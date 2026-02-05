import { dialog, shell } from 'electron';

export async function showScreenRecordingPrompt(): Promise<void> {
  const response = await dialog.showMessageBox({
    type: 'info',
    buttons: ['Open Settings', 'Not now'],
    defaultId: 0,
    cancelId: 1,
    noLink: true,
    title: 'Screen Recording Required',
    message: 'Enable Screen Recording to use this app.',
    detail: 'System Settings -> Privacy & Security -> Screen Recording\n\nIf the shortcut works, grant access to RapidLens OCR and try again.'
  });

  if (response.response === 0) {
    await shell.openExternal('x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture');
  }
}

export async function showAccessibilityPrompt(): Promise<void> {
  const response = await dialog.showMessageBox({
    type: 'info',
    buttons: ['Open Settings', 'Not now'],
    defaultId: 0,
    cancelId: 1,
    noLink: true,
    title: 'Accessibility Required',
    message: 'Enable Accessibility to use auto-paste.',
    detail: 'System Settings -> Privacy & Security -> Accessibility\n\nGrant access to RapidLens OCR to allow automatic Cmd+V.'
  });

  if (response.response === 0) {
    await shell.openExternal('x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility');
  }
}

export function shouldThrottle(lastShownAt: number, windowMs = 30_000): boolean {
  return Date.now() - lastShownAt < windowMs;
}
