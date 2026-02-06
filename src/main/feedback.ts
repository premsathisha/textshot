import { BrowserWindow, Rectangle, screen } from 'electron';

const TOAST_WIDTH = 240;
const TOAST_HEIGHT = 90;
const DEFAULT_DURATION_MS = 1000;

type TimeoutHandle = ReturnType<typeof setTimeout>;

type ToastPresenterDeps = {
  createWindow: () => BrowserWindow;
  getDisplayBounds: () => Rectangle;
  setTimer: (handler: () => void, timeoutMs: number) => TimeoutHandle;
  clearTimer: (timer: TimeoutHandle) => void;
  durationMs: number;
};

type ToastPresenter = {
  show: (message: string) => Promise<void>;
  dispose: () => void;
};

let defaultPresenter: ToastPresenter | null = null;

export async function showFeedbackToast(message: string): Promise<void> {
  if (!defaultPresenter) {
    defaultPresenter = createToastPresenter();
  }

  await defaultPresenter.show(message);
}

export function disposeFeedbackToast(): void {
  if (!defaultPresenter) return;
  defaultPresenter.dispose();
  defaultPresenter = null;
}

export function createToastPresenter(overrides: Partial<ToastPresenterDeps> = {}): ToastPresenter {
  const deps: ToastPresenterDeps = {
    createWindow: createToastWindow,
    getDisplayBounds: getActiveDisplayBounds,
    setTimer: (handler, timeoutMs) => setTimeout(handler, timeoutMs),
    clearTimer: (timer) => clearTimeout(timer),
    durationMs: DEFAULT_DURATION_MS,
    ...overrides
  };

  let toastWindow: BrowserWindow | null = null;
  let hideTimer: TimeoutHandle | null = null;

  const clearHideTimer = (): void => {
    if (!hideTimer) return;
    deps.clearTimer(hideTimer);
    hideTimer = null;
  };

  const hideToast = (): void => {
    if (!toastWindow || toastWindow.isDestroyed()) return;
    toastWindow.hide();
  };

  const ensureWindow = (): BrowserWindow => {
    if (toastWindow && !toastWindow.isDestroyed()) {
      return toastWindow;
    }

    toastWindow = deps.createWindow();
    return toastWindow;
  };

  return {
    show: async (message: string): Promise<void> => {
      clearHideTimer();

      const display = deps.getDisplayBounds();
      const x = display.x + Math.round((display.width - TOAST_WIDTH) / 2);
      const y = display.y + Math.round((display.height - TOAST_HEIGHT) / 2);

      const win = ensureWindow();
      win.setBounds({ x, y, width: TOAST_WIDTH, height: TOAST_HEIGHT });
      await win.loadURL(buildToastUrl(message));

      if (!win.isDestroyed()) {
        win.showInactive();
      }

      hideTimer = deps.setTimer(() => {
        hideToast();
        hideTimer = null;
      }, deps.durationMs);
    },
    dispose: (): void => {
      clearHideTimer();
      if (!toastWindow || toastWindow.isDestroyed()) {
        toastWindow = null;
        return;
      }

      toastWindow.destroy();
      toastWindow = null;
    }
  };
}

function createToastWindow(): BrowserWindow {
  const window = new BrowserWindow({
    width: TOAST_WIDTH,
    height: TOAST_HEIGHT,
    frame: false,
    transparent: true,
    show: false,
    resizable: false,
    minimizable: false,
    maximizable: false,
    movable: false,
    focusable: false,
    skipTaskbar: true,
    hasShadow: false,
    webPreferences: {
      backgroundThrottling: false,
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false
    }
  });

  window.setAlwaysOnTop(true, 'screen-saver');
  window.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  window.setIgnoreMouseEvents(true);
  return window;
}

function getActiveDisplayBounds(): Rectangle {
  const point = screen.getCursorScreenPoint();
  return screen.getDisplayNearestPoint(point).bounds;
}

function buildToastUrl(message: string): string {
  const safeMessage = escapeHtml(message);
  const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      html, body {
        width: 100%;
        height: 100%;
        margin: 0;
        background: transparent;
      }
      body {
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .toast {
        border-radius: 12px;
        padding: 14px 24px;
        color: #ffffff;
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Helvetica, Arial, sans-serif;
        font-size: 18px;
        font-weight: 600;
        letter-spacing: 0.01em;
        background: rgba(24, 24, 24, 0.52);
        border: 1px solid rgba(255, 255, 255, 0.24);
        backdrop-filter: blur(10px);
        -webkit-backdrop-filter: blur(10px);
      }
    </style>
  </head>
  <body>
    <div class="toast">${safeMessage}</div>
  </body>
</html>`;

  return `data:text/html;charset=utf-8,${encodeURIComponent(html)}`;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
