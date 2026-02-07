import { beforeEach, describe, expect, it, vi } from 'vitest';

const mockState = vi.hoisted(() => {
  const browserWindowInstances: MockBrowserWindow[] = [];
  const browserWindowCtor = vi.fn((options: Record<string, unknown>) => {
    const instance = new MockBrowserWindow(options);
    browserWindowInstances.push(instance);
    return instance;
  });

  const getCursorScreenPoint = vi.fn(() => ({ x: 500, y: 420 }));
  const getDisplayNearestPoint = vi.fn(() => ({
    bounds: { x: 100, y: 50, width: 1600, height: 900 }
  }));

  return {
    browserWindowInstances,
    browserWindowCtor,
    getCursorScreenPoint,
    getDisplayNearestPoint
  };
});

vi.mock('electron', () => ({
  BrowserWindow: mockState.browserWindowCtor,
  screen: {
    getCursorScreenPoint: mockState.getCursorScreenPoint,
    getDisplayNearestPoint: mockState.getDisplayNearestPoint
  }
}));

import { createToastPresenter } from '../../src/main/feedback';

class MockBrowserWindow {
  public readonly options: Record<string, unknown>;
  public readonly loadURL = vi.fn(async () => {});
  public readonly setBounds = vi.fn();
  public readonly showInactive = vi.fn();
  public readonly hide = vi.fn();
  public readonly setAlwaysOnTop = vi.fn();
  public readonly setVisibleOnAllWorkspaces = vi.fn();
  public readonly setIgnoreMouseEvents = vi.fn();
  public readonly webContents = {
    executeJavaScript: vi.fn(async () => {})
  };

  private destroyed = false;

  constructor(options: Record<string, unknown>) {
    this.options = options;
  }

  isDestroyed(): boolean {
    return this.destroyed;
  }

  destroy(): void {
    this.destroyed = true;
  }
}

describe('createToastPresenter', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    mockState.browserWindowCtor.mockClear();
    mockState.browserWindowInstances.length = 0;
    mockState.getCursorScreenPoint.mockClear();
    mockState.getDisplayNearestPoint.mockClear();
  });

  it('creates and reuses a single window while updating messages', async () => {
    const presenter = createToastPresenter();

    await presenter.show('Copied!');
    await presenter.show('Error');

    expect(mockState.browserWindowCtor).toHaveBeenCalledTimes(1);
    const firstWindow = mockState.browserWindowInstances[0];
    expect(firstWindow.loadURL).toHaveBeenCalledTimes(2);
    expect(firstWindow.loadURL.mock.calls[0]?.[0]).toContain('Copied!');
    expect(firstWindow.loadURL.mock.calls[1]?.[0]).toContain('Error');
  });

  it('centers toast in active display bounds', async () => {
    const presenter = createToastPresenter();
    await presenter.show('No text');

    const firstWindow = mockState.browserWindowInstances[0];
    expect(firstWindow.setBounds).toHaveBeenCalledWith({
      x: 780,
      y: 455,
      width: 240,
      height: 90
    });
  });

  it('auto-hides after timeout and resets timer on repeated calls', async () => {
    const presenter = createToastPresenter();
    await presenter.show('Copied!');

    const firstWindow = mockState.browserWindowInstances[0];
    vi.advanceTimersByTime(1019);
    expect(firstWindow.hide).not.toHaveBeenCalled();

    await presenter.show('Error');
    vi.advanceTimersByTime(1019);
    expect(firstWindow.hide).not.toHaveBeenCalled();

    vi.advanceTimersByTime(181);
    expect(firstWindow.hide).toHaveBeenCalledTimes(1);
  });

  it('creates the toast window with native HUD material and active visual effect state', async () => {
    const presenter = createToastPresenter();
    await presenter.show('Copied!');

    const firstWindow = mockState.browserWindowInstances[0];
    expect(firstWindow.options.vibrancy).toBe('hud');
    expect(firstWindow.options.visualEffectState).toBe('active');
    expect(firstWindow.options.focusable).toBe(false);
    expect(firstWindow.options.hasShadow).toBe(true);
  });
});
