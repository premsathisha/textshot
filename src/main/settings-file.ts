import fs from 'node:fs';

export type AppSettings = {
  hotkey: string;
  showConfirmation: boolean;
  launchAtLogin: boolean;
  debugMode: boolean;
  autoPaste: boolean;
  lastPermissionPromptAt: number;
  lastAccessibilityPromptAt: number;
};

export const DEFAULT_SETTINGS: AppSettings = {
  hotkey: 'CommandOrControl+Shift+2',
  showConfirmation: true,
  launchAtLogin: false,
  debugMode: false,
  autoPaste: false,
  lastPermissionPromptAt: 0,
  lastAccessibilityPromptAt: 0
};

export function readSettingsFile(filePath: string): AppSettings {
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export function writeSettingsFile(filePath: string, settings: AppSettings): void {
  fs.writeFileSync(filePath, JSON.stringify(settings, null, 2), { encoding: 'utf8' });
}

export function updateSettingsFile(filePath: string, partial: Partial<AppSettings>): AppSettings {
  const current = readSettingsFile(filePath);
  const merged = { ...current, ...partial };
  const next: AppSettings = {
    ...merged,
    hotkey: merged.hotkey || DEFAULT_SETTINGS.hotkey
  };

  writeSettingsFile(filePath, next);
  return { ...next };
}
