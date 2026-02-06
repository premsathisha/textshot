import { Tray } from 'electron';

export async function pulseTray(tray: Tray, text: string): Promise<void> {
  const originalTitle = tray.getTitle();
  tray.setTitle(text);
  await sleep(1000);
  tray.setTitle(originalTitle);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
