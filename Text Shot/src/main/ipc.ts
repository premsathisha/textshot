import { BrowserWindow, IpcMain, app } from 'electron';
import { SettingsStore } from './settings-store';
import { registerHotkey } from './hotkey';

type IpcDeps = {
  ipcMain: IpcMain;
  store: SettingsStore;
  onHotkeyChange: () => void;
  getSettingsWindow: () => BrowserWindow | null;
};

export function registerIpc({ ipcMain, store, onHotkeyChange, getSettingsWindow }: IpcDeps): void {
  ipcMain.handle('settings:get', () => store.get());

  ipcMain.handle('settings:update', (_event, partial) => {
    const next = store.update(partial || {});
    app.setLoginItemSettings({ openAtLogin: next.launchAtLogin });
    onHotkeyChange();

    const win = getSettingsWindow();
    if (win && !win.isDestroyed()) {
      win.webContents.send('settings:changed', next);
    }

    return next;
  });
}
