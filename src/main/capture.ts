import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export type CaptureResult = {
  canceled: boolean;
  path?: string;
  error?: string;
};

export async function captureRegion(): Promise<CaptureResult> {
  const filePath = path.join(os.tmpdir(), `rapidlens-capture-${Date.now()}-${Math.random().toString(16).slice(2)}.png`);

  const { code, stderr } = await run('/usr/sbin/screencapture', ['-i', '-x', filePath]);

  if (code === 0 && fs.existsSync(filePath)) {
    return { canceled: false, path: filePath };
  }

  if (fs.existsSync(filePath)) {
    fs.rmSync(filePath, { force: true });
  }

  if (code === 1) {
    return { canceled: true };
  }

  return { canceled: false, error: stderr || `screencapture exited with ${code}` };
}

function run(command: string, args: string[]): Promise<{ code: number | null; stderr: string }> {
  return new Promise((resolve) => {
    const child = spawn(command, args);
    let stderr = '';

    child.stderr.on('data', (chunk) => {
      stderr += String(chunk);
    });

    child.on('close', (code) => {
      resolve({ code, stderr: stderr.trim() });
    });

    child.on('error', (error) => {
      resolve({ code: -1, stderr: error.message });
    });
  });
}
