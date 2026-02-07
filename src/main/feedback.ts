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
  let shellLoaded = false;
  let hideTimer: TimeoutHandle | null = null;
  let fadeTimer: TimeoutHandle | null = null;
  let displayToken = 0;

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

  const hideToast = (token: number): void => {
    if (token !== displayToken) return;
    if (!toastWindow || toastWindow.isDestroyed()) return;
    void toastWindow.webContents.executeJavaScript('window.__textShotHide?.();', true).catch(() => {
      recreateToastWindow();
    });

    fadeTimer = deps.setTimer(() => {
      if (token !== displayToken) return;
      fadeTimer = null;
      if (!toastWindow || toastWindow.isDestroyed()) return;
      toastWindow.hide();
    }, TOAST_ANIMATION_MS);
  };

  const recreateToastWindow = (): void => {
    if (toastWindow && !toastWindow.isDestroyed()) {
      toastWindow.destroy();
    }
    toastWindow = null;
    shellLoaded = false;
    clearHideTimers();
  };

  const ensureWindow = (): BrowserWindow => {
    if (toastWindow && !toastWindow.isDestroyed()) {
      return toastWindow;
    }

    toastWindow = deps.createWindow();
    shellLoaded = false;
    return toastWindow;
  };

  const ensureShellLoaded = async (window: BrowserWindow): Promise<void> => {
    if (shellLoaded) return;
    await window.loadURL(buildToastShellUrl());
    shellLoaded = true;
  };

  const updateMessage = async (window: BrowserWindow, message: string): Promise<void> => {
    const safeMessage = escapeForJavaScriptString(message);
    await window.webContents.executeJavaScript(`window.__textShotSetMessage?.('${safeMessage}');`, true);
  };

  return {
    show: async (message: string): Promise<void> => {
      clearHideTimers();
      displayToken += 1;
      const token = displayToken;

      const display = deps.getDisplayBounds();
      const x = display.x + Math.round((display.width - TOAST_WIDTH) / 2);
      const y = display.y + Math.round((display.height - TOAST_HEIGHT) / 2);

      let win = ensureWindow();
      win.setBounds({ x, y, width: TOAST_WIDTH, height: TOAST_HEIGHT });
      try {
        await ensureShellLoaded(win);
        await updateMessage(win, message);
      } catch {
        recreateToastWindow();
        win = ensureWindow();
        win.setBounds({ x, y, width: TOAST_WIDTH, height: TOAST_HEIGHT });
        await ensureShellLoaded(win);
        await updateMessage(win, message);
      }

      if (!win.isDestroyed()) {
        win.setVibrancy('hud');
        win.showInactive();
        void win.webContents.executeJavaScript('window.__textShotShow?.();', true).catch(() => {
          recreateToastWindow();
        });
      }

      hideTimer = deps.setTimer(() => {
        if (token !== displayToken) return;
        hideTimer = null;
        hideToast(token);
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

function buildToastShellUrl(): string {
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
      window.__textShotSetMessage = (message) => {
        const node = document.getElementById('toast-message');
        if (!node) return;
        node.textContent = message;
      };
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
    <div id="toast-message" class="toast"></div>
  </body>
</html>`;

  return `data:text/html;charset=utf-8,${encodeURIComponent(html)}`;
}

function escapeForJavaScriptString(value: string): string {
  return value
    .replaceAll('\\', '\\\\')
    .replaceAll("'", "\\'")
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r')
    .replaceAll('\u2028', '\\u2028')
    .replaceAll('\u2029', '\\u2029');
}
