import { app, BrowserWindow, clipboard, ipcMain } from 'electron';
import fs from 'node:fs';
import path from 'node:path';
import { ChildProcess, spawn } from 'node:child_process';
import { createTray } from './tray';
import { activateHotkey, getActiveHotkey, unregisterHotkeys } from './hotkey';
import { captureRegion } from './capture';
import { runOcrWithRetry } from './ocr';
import { SettingsStore } from './settings-store';
import { disposeFeedbackToast, showFeedbackToast } from './feedback';
import { registerIpc } from './ipc';
import { shouldThrottle, showAccessibilityPrompt, showScreenRecordingPrompt } from './permissions';
import { buildNativeSettingsArgs, resolveNativeSettingsBinaryPath } from './native-settings';
import { configureAutoUpdater } from './updater';

let settingsWindow: BrowserWindow | null = null;
let tray = null as ReturnType<typeof createTray> | null;
let lastCopiedText = '';
let nativeSettingsProcess: ChildProcess | null = null;
let settingsFileWatcher: fs.FSWatcher | null = null;
let settingsWatchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

const DEFAULT_HOTKEY = 'CommandOrControl+Shift+2';
const SETTINGS_FILE_WATCH_DEBOUNCE_MS = 120;

const store = new SettingsStore();

function bringSettingsWindowToFront(window: BrowserWindow): void {
  if (window.isDestroyed()) return;
  if (window.isMinimized()) {
    window.restore();
  }

  app.focus({ steal: true });
  window.show();
  window.focus();
  window.moveTop();
}

function createSettingsWindow(): void {
  if (settingsWindow && !settingsWindow.isDestroyed()) {
    bringSettingsWindowToFront(settingsWindow);
    return;
  }

  settingsWindow = new BrowserWindow({
    width: 360,
    height: 340,
    resizable: false,
    maximizable: false,
    minimizable: false,
    show: false,
    title: 'Text Shot Settings',
    webPreferences: {
      preload: path.join(__dirname, '../preload/settings-preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  const settingsHtml = path.join(app.getAppPath(), 'dist', 'renderer', 'settings.html');
  settingsWindow.loadFile(settingsHtml).catch(() => {
    /* no-op: fallback window remains closed if renderer fails to load */
  });
  settingsWindow.once('ready-to-show', () => {
    if (!settingsWindow || settingsWindow.isDestroyed()) return;
    bringSettingsWindowToFront(settingsWindow);
  });
  settingsWindow.on('closed', () => {
    settingsWindow = null;
  });
}

function notifySettingsWindowChanged(): void {
  const win = settingsWindow;
  if (win && !win.isDestroyed()) {
    win.webContents.send('settings:changed', store.get());
  }
}

type HotkeyApplyResult = {
  applied: boolean;
  requestedHotkey: string;
  activeHotkey: string | null;
  usedFallback: boolean;
};

function applyHotkey(): HotkeyApplyResult {
  const requestedHotkey = store.get().hotkey.trim();

  const requestedApplied = activateHotkey(requestedHotkey, () => {
    void runCaptureFlow();
  });
  if (requestedApplied) {
    return {
      applied: true,
      requestedHotkey,
      activeHotkey: getActiveHotkey(),
      usedFallback: false
    };
  }

  const existingActiveHotkey = getActiveHotkey();
  if (existingActiveHotkey) {
    return {
      applied: false,
      requestedHotkey,
      activeHotkey: existingActiveHotkey,
      usedFallback: false
    };
  }

  const fallbackApplied = activateHotkey(DEFAULT_HOTKEY, () => {
    void runCaptureFlow();
  });
  return {
    applied: fallbackApplied,
    requestedHotkey,
    activeHotkey: getActiveHotkey(),
    usedFallback: fallbackApplied
  };
}

function applyPersistedSettings(options: { repairHotkeyOnFailure?: boolean } = {}): void {
  const { repairHotkeyOnFailure = false } = options;
  store.reloadFromDisk();
  const hotkeyResult = applyHotkey();

  if (
    repairHotkeyOnFailure &&
    hotkeyResult.activeHotkey &&
    hotkeyResult.requestedHotkey !== hotkeyResult.activeHotkey &&
    (!hotkeyResult.applied || hotkeyResult.usedFallback)
  ) {
    store.update({ hotkey: hotkeyResult.activeHotkey });
  }

  if (app.isPackaged) {
    app.setLoginItemSettings({ openAtLogin: store.get().launchAtLogin });
  }

  notifySettingsWindowChanged();
}

function stopSettingsFileWatcher(): void {
  if (settingsWatchDebounceTimer) {
    clearTimeout(settingsWatchDebounceTimer);
    settingsWatchDebounceTimer = null;
  }

  if (!settingsFileWatcher) return;
  settingsFileWatcher.close();
  settingsFileWatcher = null;
}

function scheduleSettingsReloadFromDisk(): void {
  if (settingsWatchDebounceTimer) {
    clearTimeout(settingsWatchDebounceTimer);
  }

  settingsWatchDebounceTimer = setTimeout(() => {
    settingsWatchDebounceTimer = null;
    applyPersistedSettings({ repairHotkeyOnFailure: true });
  }, SETTINGS_FILE_WATCH_DEBOUNCE_MS);
}

function startSettingsFileWatcher(): void {
  if (settingsFileWatcher) return;

  const settingsFilePath = store.getFilePath();
  const settingsDirectory = path.dirname(settingsFilePath);
  const settingsFileName = path.basename(settingsFilePath);

  try {
    settingsFileWatcher = fs.watch(settingsDirectory, (_eventType, filename) => {
      if (filename && filename.toString() !== settingsFileName) {
        return;
      }

      scheduleSettingsReloadFromDisk();
    });
    settingsFileWatcher.on('error', () => {
      stopSettingsFileWatcher();
    });
  } catch {
    settingsFileWatcher = null;
  }
}

function clearNativeSettingsProcessReference(): void {
  stopSettingsFileWatcher();
  nativeSettingsProcess = null;
}

function requestNativeSettingsFocus(): boolean {
  if (!nativeSettingsProcess || nativeSettingsProcess.exitCode !== null) {
    return false;
  }

  try {
    nativeSettingsProcess.kill('SIGUSR1');
    startSettingsFileWatcher();
    return true;
  } catch {
    clearNativeSettingsProcessReference();
    return false;
  }
}

function openNativeSettings(): boolean {
  if (requestNativeSettingsFocus()) {
    return true;
  }

  const binaryPath = resolveNativeSettingsBinaryPath({
    isPackaged: app.isPackaged,
    resourcesPath: process.resourcesPath,
    appPath: app.getAppPath()
  });
  if (!binaryPath) return false;

  try {
    nativeSettingsProcess = spawn(binaryPath, buildNativeSettingsArgs(store.getFilePath()), {
      stdio: 'ignore'
    });
  } catch {
    clearNativeSettingsProcessReference();
    return false;
  }

  startSettingsFileWatcher();

  nativeSettingsProcess.once('error', () => {
    clearNativeSettingsProcessReference();
    createSettingsWindow();
  });

  nativeSettingsProcess.once('close', () => {
    clearNativeSettingsProcessReference();
    applyPersistedSettings({ repairHotkeyOnFailure: true });
  });

  return true;
}

async function maybeAutoPaste(): Promise<boolean> {
  return new Promise((resolve) => {
    const script = 'tell application "System Events" to keystroke "v" using command down';
    const child = spawn('/usr/bin/osascript', ['-e', script]);
    child.on('close', (code) => resolve(code === 0));
    child.on('error', () => resolve(false));
  });
}

async function runCaptureFlow(): Promise<void> {
  const settings = store.get();
  const captured = await captureRegion();

  if (captured.canceled) return;

  if (!captured.path) {
    if (shouldThrottle(settings.lastPermissionPromptAt)) return;
    store.update({ lastPermissionPromptAt: Date.now() });
    await showScreenRecordingPrompt();
    return;
  }

  try {
    const ocr = await runOcrWithRetry(captured.path);

    if (!ocr || ocr.text.trim().length === 0) {
      if (settings.showConfirmation) {
        await showFeedbackToast('No text');
      }
      return;
    }

    if (ocr.text === lastCopiedText) {
      clipboard.writeText(ocr.text);
      return;
    }

    clipboard.writeText(ocr.text);
    lastCopiedText = ocr.text;

    if (settings.autoPaste) {
      const pasted = await maybeAutoPaste();
      if (!pasted && !shouldThrottle(settings.lastAccessibilityPromptAt)) {
        store.update({ lastAccessibilityPromptAt: Date.now() });
        await showAccessibilityPrompt();
      }
    }

    if (settings.showConfirmation) {
      await showFeedbackToast('Copied!');
    }
  } catch {
    if (settings.showConfirmation) {
      await showFeedbackToast('Error');
    }
  } finally {
    const latest = store.get();
    if (!latest.debugMode && captured.path && fs.existsSync(captured.path)) {
      fs.rmSync(captured.path, { force: true });
    }
  }
}

function bootstrap(): void {
  if (process.platform === 'darwin' && app.dock) {
    app.dock.hide();
  }

  const updater = configureAutoUpdater({
    autoCheckOnLaunch: process.env.TEXT_SHOT_AUTO_UPDATE_ON_LAUNCH !== 'false',
    includePrerelease: process.env.TEXT_SHOT_INCLUDE_PRERELEASE_UPDATES === 'true'
  });

  tray = createTray(
    () => void runCaptureFlow(),
    () => {
      if (!openNativeSettings()) {
        createSettingsWindow();
      }
    },
    () => {
      void updater.checkForUpdates({ manual: true });
    },
    () => app.quit()
  );

  applyPersistedSettings({ repairHotkeyOnFailure: true });

  registerIpc({
    ipcMain,
    store,
    onHotkeyChange: () => applyPersistedSettings({ repairHotkeyOnFailure: true }),
    getSettingsWindow: () => settingsWindow
  });

  if (updater.checkOnLaunch) {
    void updater.checkForUpdates();
  }
}

app.whenReady().then(bootstrap);

app.on('will-quit', () => {
  stopSettingsFileWatcher();
  disposeFeedbackToast();
  unregisterHotkeys();
});

app.on('activate', () => {
  if (!tray) {
    bootstrap();
  }
});
