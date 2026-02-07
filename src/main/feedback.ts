import { BrowserWindow, Rectangle, screen } from 'electron';

const TOAST_WIDTH = 240;
const TOAST_HEIGHT = 90;
const DEFAULT_DURATION_MS = 1020;
const TOAST_ANIMATION_MS = 180;

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
  let fadeTimer: TimeoutHandle | null = null;

  const clearHideTimers = (): void => {
    if (hideTimer) {
      deps.clearTimer(hideTimer);
      hideTimer = null;
    }

    if (fadeTimer) {
      deps.clearTimer(fadeTimer);
      fadeTimer = null;
    }
  };

  const hideToast = (): void => {
    if (!toastWindow || toastWindow.isDestroyed()) return;
    void toastWindow.webContents.executeJavaScript('window.__textShotHide?.();', true).catch(() => {
      /* no-op: animation fallback to immediate hide */
    });

    fadeTimer = deps.setTimer(() => {
      fadeTimer = null;
      if (!toastWindow || toastWindow.isDestroyed()) return;
      toastWindow.hide();
    }, TOAST_ANIMATION_MS);
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
      clearHideTimers();

      const display = deps.getDisplayBounds();
      const x = display.x + Math.round((display.width - TOAST_WIDTH) / 2);
      const y = display.y + Math.round((display.height - TOAST_HEIGHT) / 2);

      const win = ensureWindow();
      win.setBounds({ x, y, width: TOAST_WIDTH, height: TOAST_HEIGHT });
      await win.loadURL(buildToastUrl(message));

      if (!win.isDestroyed()) {
        win.showInactive();
        void win.webContents.executeJavaScript('window.__textShotShow?.();', true).catch(() => {
          /* no-op: toast is still visible without the helper */
        });
      }

      hideTimer = deps.setTimer(() => {
        hideTimer = null;
        hideToast();
      }, deps.durationMs);
    },
    dispose: (): void => {
      clearHideTimers();
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
    hasShadow: true,
    vibrancy: 'hud',
    visualEffectState: 'active',
    backgroundColor: '#00000000',
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
        overflow: hidden;
      }
      body {
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 8px;
        box-sizing: border-box;
        color-scheme: light dark;
      }
      body.ready .toast {
        opacity: 1;
        transform: scale(1);
      }
      body.hiding .toast {
        opacity: 0;
        transform: scale(0.985);
      }
      .toast {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 12px;
        padding: 14px;
        box-sizing: border-box;
        color: #181b22;
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Helvetica, Arial, sans-serif;
        font-size: 17px;
        font-weight: 600;
        letter-spacing: 0.01em;
        border: none;
        background: transparent;
        box-shadow: 0 8px 22px rgba(16, 20, 28, 0.16);
        opacity: 0;
        transform: scale(0.96);
        transition: opacity ${TOAST_ANIMATION_MS}ms ease, transform ${TOAST_ANIMATION_MS}ms ease;
      }
      @media (prefers-color-scheme: dark) {
        .toast {
          color: #f3f5f7;
        }
      }
    </style>
    <script>
      window.__textShotShow = () => {
        document.body.classList.remove('hiding');
        requestAnimationFrame(() => {
          document.body.classList.add('ready');
        });
      };
      window.__textShotHide = () => {
        document.body.classList.remove('ready');
        document.body.classList.add('hiding');
      };
      window.addEventListener('DOMContentLoaded', () => {
        window.__textShotShow();
      });
    </script>
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
