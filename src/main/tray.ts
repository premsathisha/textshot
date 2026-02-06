import { Menu, Tray, app, nativeImage } from 'electron';
import path from 'node:path';

export function createTray(onCapture: () => void, onOpenSettings: () => void, onQuit: () => void): Tray {
  const imagePath = path.join(app.getAppPath(), 'assets', 'trayTemplate.png');
  const icon = nativeImage.createFromPath(imagePath);
  const tray = new Tray(icon.isEmpty() ? nativeImage.createEmpty() : icon);
  tray.setToolTip('Text Shot');
  tray.setTitle('');

  const menu = Menu.buildFromTemplate([
    { label: 'Capture Text', click: onCapture },
    { type: 'separator' },
    { label: 'Settings', click: onOpenSettings },
    { type: 'separator' },
    { label: 'Quit', click: onQuit }
  ]);

  tray.setContextMenu(menu);
  return tray;
}
