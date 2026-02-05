import { app } from 'electron';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

export type OcrResult = {
  text: string;
  level: 'accurate' | 'fast';
};

const RETRY_CHAIN: Array<{ level: 'accurate' | 'fast'; correction: boolean }> = [
  { level: 'accurate', correction: true },
  { level: 'accurate', correction: false },
  { level: 'fast', correction: true }
];

export async function runOcrWithRetry(inputPath: string): Promise<OcrResult | null> {
  for (const attempt of RETRY_CHAIN) {
    const result = await runHelper(inputPath, attempt.level, attempt.correction);
    if (result.text.trim().length > 0) {
      return {
        text: cleanupOcrText(result.text),
        level: attempt.level
      };
    }
  }

  return null;
}

export function cleanupOcrText(input: string): string {
  const lines = input
    .replace(/\r\n/g, '\n')
    .split('\n')
    .map((line) => line.replace(/[ \t]+$/g, ''));

  const filtered = lines.filter((line) => {
    if (line.trim().length === 0) return true;
    if (/^[|`~.,:;]+$/.test(line.trim())) return false;
    return true;
  });

  return filtered.join('\n').replace(/\n{3,}/g, '\n\n').trim();
}

async function runHelper(inputPath: string, level: 'accurate' | 'fast', languageCorrection: boolean): Promise<{ text: string }> {
  const helperPath = resolveHelperPath();
  const args = ['--input', inputPath, '--level', level, '--language-correction', languageCorrection ? 'on' : 'off'];

  return new Promise((resolve, reject) => {
    const child = spawn(helperPath, args);
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += String(chunk);
    });

    child.stderr.on('data', (chunk) => {
      stderr += String(chunk);
    });

    child.on('close', (code) => {
      if (code === 0 || code === 10) {
        resolve({ text: stdout.trimEnd() });
      } else {
        reject(new Error(stderr.trim() || `ocr-helper failed with code ${code}`));
      }
    });

    child.on('error', (error) => reject(error));
  });
}

function resolveHelperPath(): string {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'bin', 'ocr-helper');
  }

  const devPath = path.join(app.getAppPath(), 'bin', 'ocr-helper');
  if (fs.existsSync(devPath)) {
    return devPath;
  }

  return path.join(app.getAppPath(), 'native', 'ocr-helper', '.build', 'debug', 'ocr-helper');
}
