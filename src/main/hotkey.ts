import { globalShortcut } from 'electron';

export function registerHotkey(accelerator: string, handler: () => void): boolean {
  globalShortcut.unregisterAll();
  return globalShortcut.register(accelerator, handler);
}

export function unregisterHotkeys(): void {
  globalShortcut.unregisterAll();
}
