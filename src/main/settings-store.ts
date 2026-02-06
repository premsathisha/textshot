import { app } from 'electron';
import path from 'node:path';
import { AppSettings, readSettingsFile, updateSettingsFile } from './settings-file';

export type { AppSettings };

export class SettingsStore {
  private readonly filePath: string;
  private settings: AppSettings;

  constructor() {
    this.filePath = path.join(app.getPath('userData'), 'settings.json');
    this.settings = readSettingsFile(this.filePath);
  }

  get(): AppSettings {
    return { ...this.settings };
  }

  getFilePath(): string {
    return this.filePath;
  }

  update(partial: Partial<AppSettings>): AppSettings {
    this.settings = updateSettingsFile(this.filePath, partial);
    return this.get();
  }

  reloadFromDisk(): AppSettings {
    this.settings = readSettingsFile(this.filePath);
    return this.get();
  }
}
