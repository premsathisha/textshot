import { contextBridge, ipcRenderer } from 'electron';

type Settings = {
  hotkey: string;
  showConfirmation: boolean;
  launchAtLogin: boolean;
  debugMode: boolean;
  autoPaste: boolean;
};

contextBridge.exposeInMainWorld('settingsApi', {
  get: (): Promise<Settings> => ipcRenderer.invoke('settings:get'),
  update: (partial: Partial<Settings>): Promise<Settings> => ipcRenderer.invoke('settings:update', partial),
  onChanged: (callback: (settings: Settings) => void) => {
    ipcRenderer.on('settings:changed', (_event, settings) => callback(settings));
  }
});
