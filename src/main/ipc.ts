import { BrowserWindow, IpcMain, app } from 'electron';
import { SettingsStore } from './settings-store';

type IpcDeps = {
  ipcMain: IpcMain;
  store: SettingsStore;
  onHotkeyChange: () => void;
  getSettingsWindow: () => BrowserWindow | null;
};

export function registerIpc({ ipcMain, store, onHotkeyChange, getSettingsWindow }: IpcDeps): void {
  ipcMain.handle('settings:get', () => store.get());

  ipcMain.handle('settings:update', (_event, partial) => {
    store.update(partial || {});
    if (app.isPackaged) {
      app.setLoginItemSettings({ openAtLogin: store.get().launchAtLogin });
    }
    onHotkeyChange();
    const next = store.reloadFromDisk();

    const win = getSettingsWindow();
    if (win && !win.isDestroyed()) {
      win.webContents.send('settings:changed', next);
    }

    return next;
  });
}
