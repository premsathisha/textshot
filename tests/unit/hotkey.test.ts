import { beforeEach, describe, expect, it, vi } from 'vitest';

const mockState = vi.hoisted(() => {
  const register = vi.fn();
  const unregister = vi.fn();
  const unregisterAll = vi.fn();

  return {
    register,
    unregister,
    unregisterAll
  };
});

vi.mock('electron', () => ({
  globalShortcut: {
    register: mockState.register,
    unregister: mockState.unregister,
    unregisterAll: mockState.unregisterAll
  }
}));

import { activateHotkey, getActiveHotkey, unregisterHotkeys } from '../../src/main/hotkey';

describe('hotkey activation', () => {
  beforeEach(() => {
    mockState.register.mockReset();
    mockState.unregister.mockReset();
    mockState.unregisterAll.mockReset();
    unregisterHotkeys();
  });

  it('keeps the old shortcut when new registration fails', () => {
    mockState.register.mockReturnValueOnce(true).mockReturnValueOnce(false);

    expect(activateHotkey('CommandOrControl+Shift+2', () => {})).toBe(true);
    expect(getActiveHotkey()).toBe('CommandOrControl+Shift+2');

    expect(activateHotkey('Control+Alt+K', () => {})).toBe(false);
    expect(getActiveHotkey()).toBe('CommandOrControl+Shift+2');
    expect(mockState.unregister).not.toHaveBeenCalled();
  });

  it('switches to the new shortcut only after successful registration', () => {
    mockState.register.mockReturnValue(true);

    expect(activateHotkey('CommandOrControl+Shift+2', () => {})).toBe(true);
    expect(activateHotkey('Control+Alt+K', () => {})).toBe(true);

    expect(mockState.unregister).toHaveBeenCalledWith('CommandOrControl+Shift+2');
    expect(getActiveHotkey()).toBe('Control+Alt+K');
  });
});
