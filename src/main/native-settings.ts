import fs from 'node:fs';
import path from 'node:path';

type ResolveBinaryPathInput = {
  isPackaged: boolean;
  resourcesPath: string;
  appPath: string;
};

export function resolveNativeSettingsBinaryPath(input: ResolveBinaryPathInput): string | null {
  if (input.isPackaged) {
    const packagedPath = path.join(input.resourcesPath, 'bin', 'text-shot-settings');
    return fs.existsSync(packagedPath) ? packagedPath : null;
  }

  const candidates = [
    path.join(input.appPath, 'bin', 'text-shot-settings'),
    path.join(input.appPath, 'native', 'settings-app', '.build', 'release', 'text-shot-settings'),
    path.join(input.appPath, 'native', 'settings-app', '.build', 'debug', 'text-shot-settings')
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return null;
}

export function buildNativeSettingsArgs(settingsFilePath: string): string[] {
  return ['--settings-file', settingsFilePath];
}
