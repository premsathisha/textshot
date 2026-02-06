import { app, dialog } from 'electron';

type CheckForUpdatesOptions = {
  manual?: boolean;
};

type ConfigureAutoUpdaterOptions = {
  autoCheckOnLaunch: boolean;
  includePrerelease: boolean;
};

type UpdaterController = {
  checkOnLaunch: boolean;
  checkForUpdates: (options?: CheckForUpdatesOptions) => Promise<void>;
};

type AutoUpdaterLike = {
  autoDownload?: boolean;
  autoInstallOnAppQuit?: boolean;
  allowPrerelease?: boolean;
  logger?: Console;
  on: (event: string, callback: (...args: any[]) => void) => void;
  checkForUpdates: () => Promise<{ updateInfo?: { version?: string } } | null>;
  quitAndInstall: () => void;
};

function resolveAutoUpdater(): AutoUpdaterLike | null {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const mod = require('electron-updater') as { autoUpdater?: AutoUpdaterLike };
    if (mod.autoUpdater) return mod.autoUpdater;
  } catch (error) {
    console.warn('[updater] electron-updater is not installed yet', error);
  }

  return null;
}

function isUpdaterEnabled(): boolean {
  return app.isPackaged;
}

function toMessage(error: unknown): string {
  if (error instanceof Error && error.message) return error.message;
  return String(error);
}

export function configureAutoUpdater(options: ConfigureAutoUpdaterOptions): UpdaterController {
  const autoUpdater = resolveAutoUpdater();
  if (!autoUpdater) {
    return {
      checkOnLaunch: options.autoCheckOnLaunch,
      async checkForUpdates(): Promise<void> {
        console.warn('[updater] check skipped because electron-updater is unavailable');
      }
    };
  }

  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;
  autoUpdater.allowPrerelease = options.includePrerelease;
  autoUpdater.logger = console;

  autoUpdater.on('checking-for-update', () => {
    console.info('[updater] checking for update');
  });

  autoUpdater.on('update-available', (info) => {
    console.info(`[updater] update available: ${info.version}`);
  });

  autoUpdater.on('update-not-available', (info) => {
    console.info(`[updater] no update available; current latest: ${info.version}`);
  });

  autoUpdater.on('download-progress', (progress) => {
    console.info(
      `[updater] download ${progress.percent.toFixed(1)}% (${Math.round(progress.bytesPerSecond / 1024)} KB/s)`
    );
  });

  autoUpdater.on('error', (error) => {
    console.error('[updater] error', error);
  });

  autoUpdater.on('update-downloaded', async (info) => {
    console.info(`[updater] downloaded version ${info.version}`);
    const result = await dialog.showMessageBox({
      type: 'info',
      buttons: ['Install and Relaunch', 'Later'],
      defaultId: 0,
      cancelId: 1,
      title: 'Update Ready',
      message: `Text Shot ${info.version} has been downloaded.`,
      detail: 'Restart now to apply the update.'
    });

    if (result.response === 0) {
      setImmediate(() => {
        autoUpdater.quitAndInstall();
      });
    }
  });

  return {
    checkOnLaunch: options.autoCheckOnLaunch,
    async checkForUpdates(checkOptions?: CheckForUpdatesOptions): Promise<void> {
      const isManual = checkOptions?.manual === true;

      if (!isUpdaterEnabled()) {
        console.info('[updater] skipping check in development mode (not packaged)');
        if (isManual) {
          await dialog.showMessageBox({
            type: 'info',
            buttons: ['OK'],
            title: 'Check for Updates',
            message: 'Updates can only be checked from a packaged app build.'
          });
        }
        return;
      }

      try {
        const result = await autoUpdater.checkForUpdates();
        if (isManual && result?.updateInfo?.version) {
          const latestVersion = result.updateInfo.version;
          if (latestVersion === app.getVersion()) {
            await dialog.showMessageBox({
              type: 'info',
              buttons: ['OK'],
              title: 'Check for Updates',
              message: `Text Shot is up to date (v${app.getVersion()}).`
            });
          }
        }
      } catch (error) {
        console.error('[updater] check failed', error);
        if (isManual) {
          await dialog.showMessageBox({
            type: 'error',
            buttons: ['OK'],
            title: 'Update Check Failed',
            message: 'Unable to check for updates right now.',
            detail: toMessage(error)
          });
        }
      }
    }
  };
}
