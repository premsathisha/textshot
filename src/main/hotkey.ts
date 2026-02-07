import { globalShortcut } from 'electron';

let activeHotkey: string | null = null;

export function activateHotkey(accelerator: string, handler: () => void): boolean {
  const next = accelerator.trim();
  if (!next) return false;

  if (activeHotkey === next) {
    return true;
  }

  if (activeHotkey) {
    const registered = globalShortcut.register(next, handler);
    if (!registered) {
      return false;
    }

    globalShortcut.unregister(activeHotkey);
    activeHotkey = next;
    return true;
  }

  const registered = globalShortcut.register(next, handler);
  if (registered) {
    activeHotkey = next;
  }

  return registered;
}

export function getActiveHotkey(): string | null {
  return activeHotkey;
}

export function unregisterHotkeys(): void {
  globalShortcut.unregisterAll();
  activeHotkey = null;
}
