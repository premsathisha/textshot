import { app } from 'electron';
import fs from 'node:fs';
import path from 'node:path';

export type AppSettings = {
  hotkey: string;
  showConfirmation: boolean;
  launchAtLogin: boolean;
  debugMode: boolean;
  autoPaste: boolean;
  lastPermissionPromptAt: number;
  lastAccessibilityPromptAt: number;
};

const DEFAULT_SETTINGS: AppSettings = {
  hotkey: 'CommandOrControl+Shift+2',
  showConfirmation: true,
  launchAtLogin: false,
  debugMode: false,
  autoPaste: false,
  lastPermissionPromptAt: 0,
  lastAccessibilityPromptAt: 0
};

export class SettingsStore {
  private readonly filePath: string;
  private settings: AppSettings;

  constructor() {
    this.filePath = path.join(app.getPath('userData'), 'settings.json');
    this.settings = this.read();
  }

  get(): AppSettings {
    return { ...this.settings };
  }

  update(partial: Partial<AppSettings>): AppSettings {
    const merged = { ...this.settings, ...partial };
    this.settings = {
      ...merged,
      hotkey: merged.hotkey || DEFAULT_SETTINGS.hotkey
    };
    fs.writeFileSync(this.filePath, JSON.stringify(this.settings, null, 2));
    return this.get();
  }

  private read(): AppSettings {
    try {
      const raw = fs.readFileSync(this.filePath, 'utf8');
      return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
    } catch {
      return { ...DEFAULT_SETTINGS };
    }
  }
}
