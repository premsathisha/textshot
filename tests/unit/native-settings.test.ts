import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { buildNativeSettingsArgs, resolveNativeSettingsBinaryPath } from '../../src/main/native-settings';

describe('native-settings resolver', () => {
  it('resolves packaged binary from resources path', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'text-shot-native-packaged-'));
    const resourcesPath = path.join(dir, 'Resources');
    const packagedBin = path.join(resourcesPath, 'bin', 'text-shot-settings');
    fs.mkdirSync(path.dirname(packagedBin), { recursive: true });
    fs.writeFileSync(packagedBin, '');

    const resolved = resolveNativeSettingsBinaryPath({
      isPackaged: true,
      resourcesPath,
      appPath: '/unused'
    });

    expect(resolved).toBe(packagedBin);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('resolves dev binary from app bin folder first', () => {
    const appPath = fs.mkdtempSync(path.join(os.tmpdir(), 'text-shot-native-dev-'));
    const binPath = path.join(appPath, 'bin', 'text-shot-settings');
    fs.mkdirSync(path.dirname(binPath), { recursive: true });
    fs.writeFileSync(binPath, '');

    const resolved = resolveNativeSettingsBinaryPath({
      isPackaged: false,
      resourcesPath: '/unused',
      appPath
    });

    expect(resolved).toBe(binPath);
    fs.rmSync(appPath, { recursive: true, force: true });
  });

  it('returns null when binary cannot be found', () => {
    const resolved = resolveNativeSettingsBinaryPath({
      isPackaged: false,
      resourcesPath: '/unused',
      appPath: '/definitely-missing-path'
    });

    expect(resolved).toBeNull();
  });

  it('builds CLI args for settings file path', () => {
    expect(buildNativeSettingsArgs('/tmp/settings.json')).toEqual(['--settings-file', '/tmp/settings.json']);
  });
});
