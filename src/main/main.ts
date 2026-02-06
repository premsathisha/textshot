import { app, BrowserWindow, clipboard, ipcMain } from 'electron';
import fs from 'node:fs';
import path from 'node:path';
import { ChildProcess, spawn } from 'node:child_process';
import { createTray } from './tray';
import { registerHotkey, unregisterHotkeys } from './hotkey';
import { captureRegion } from './capture';
import { runOcrWithRetry } from './ocr';
import { SettingsStore } from './settings-store';
import { pulseTray } from './feedback';
import { registerIpc } from './ipc';
import { shouldThrottle, showAccessibilityPrompt, showScreenRecordingPrompt } from './permissions';
import { buildNativeSettingsArgs, resolveNativeSettingsBinaryPath } from './native-settings';

let settingsWindow: BrowserWindow | null = null;
let tray = null as ReturnType<typeof createTray> | null;
let lastCopiedText = '';
let nativeSettingsProcess: ChildProcess | null = null;
const store = new SettingsStore();

function createSettingsWindow(): void {
  if (settingsWindow && !settingsWindow.isDestroyed()) {
    settingsWindow.focus();
    return;
  }

  settingsWindow = new BrowserWindow({
    width: 360,
    height: 340,
    resizable: false,
    maximizable: false,
    minimizable: false,
    title: 'Text Shot Settings',
    webPreferences: {
      preload: path.join(__dirname, '../preload/settings-preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  const settingsHtml = path.join(app.getAppPath(), 'dist', 'renderer', 'settings.html');
  settingsWindow.loadFile(settingsHtml);
  settingsWindow.on('closed', () => {
    settingsWindow = null;
  });
}

function applyPersistedSettings(): void {
  store.reloadFromDisk();
  applyHotkey();

  if (app.isPackaged) {
    app.setLoginItemSettings({ openAtLogin: store.get().launchAtLogin });
  }

  const win = settingsWindow;
  if (win && !win.isDestroyed()) {
    win.webContents.send('settings:changed', store.get());
  }
}

function openNativeSettings(): boolean {
  if (nativeSettingsProcess && nativeSettingsProcess.exitCode === null) {
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
    nativeSettingsProcess = null;
    return false;
  }

  nativeSettingsProcess.once('error', () => {
    nativeSettingsProcess = null;
    createSettingsWindow();
  });

  nativeSettingsProcess.once('close', () => {
    nativeSettingsProcess = null;
    applyPersistedSettings();
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
      if (settings.showConfirmation && tray) {
        await pulseTray(tray, 'No text');
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

    if (settings.showConfirmation && tray) {
      await pulseTray(tray, 'Copied');
    }
  } catch {
    if (settings.showConfirmation && tray) {
      await pulseTray(tray, 'Error');
    }
  } finally {
    const latest = store.get();
    if (!latest.debugMode && captured.path && fs.existsSync(captured.path)) {
      fs.rmSync(captured.path, { force: true });
    }
  }
}

function applyHotkey(): void {
  const ok = registerHotkey(store.get().hotkey, () => {
    void runCaptureFlow();
  });

  if (!ok) {
    registerHotkey('CommandOrControl+Shift+2', () => {
      void runCaptureFlow();
    });
  }
}

function bootstrap(): void {
  if (process.platform === 'darwin' && app.dock) {
    app.dock.hide();
  }

  tray = createTray(
    () => void runCaptureFlow(),
    () => {
      if (!openNativeSettings()) {
        createSettingsWindow();
      }
    },
    () => app.quit()
  );

  applyHotkey();
  if (app.isPackaged) {
    app.setLoginItemSettings({ openAtLogin: store.get().launchAtLogin });
  }

  registerIpc({
    ipcMain,
    store,
    onHotkeyChange: applyHotkey,
    getSettingsWindow: () => settingsWindow
  });
}

app.whenReady().then(bootstrap);

app.on('will-quit', () => {
  unregisterHotkeys();
});

app.on('activate', () => {
  if (!tray) {
    bootstrap();
  }
});
