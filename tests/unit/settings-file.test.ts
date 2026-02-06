import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { DEFAULT_SETTINGS, readSettingsFile, updateSettingsFile } from '../../src/main/settings-file';

describe('settings-file', () => {
  it('reads defaults when file is missing', () => {
    const filePath = path.join(os.tmpdir(), `text-shot-missing-${Date.now()}.json`);
    expect(readSettingsFile(filePath)).toEqual(DEFAULT_SETTINGS);
  });

  it('updates settings and preserves existing timestamp metadata', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'text-shot-settings-'));
    const filePath = path.join(dir, 'settings.json');

    fs.writeFileSync(
      filePath,
      JSON.stringify(
        {
          ...DEFAULT_SETTINGS,
          lastPermissionPromptAt: 111,
          lastAccessibilityPromptAt: 222
        },
        null,
        2
      )
    );

    const next = updateSettingsFile(filePath, {
      hotkey: 'Control+Alt+K',
      launchAtLogin: true,
      showConfirmation: false
    });

    expect(next.hotkey).toBe('Control+Alt+K');
    expect(next.launchAtLogin).toBe(true);
    expect(next.showConfirmation).toBe(false);
    expect(next.lastPermissionPromptAt).toBe(111);
    expect(next.lastAccessibilityPromptAt).toBe(222);

    const onDisk = readSettingsFile(filePath);
    expect(onDisk).toEqual(next);

    fs.rmSync(dir, { recursive: true, force: true });
  });
});
