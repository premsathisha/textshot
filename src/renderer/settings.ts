type Settings = {
  hotkey: string;
  showConfirmation: boolean;
  launchAtLogin: boolean;
  debugMode: boolean;
  autoPaste: boolean;
};

export {};

declare global {
  interface Window {
    settingsApi: {
      get: () => Promise<Settings>;
      update: (partial: Partial<Settings>) => Promise<Settings>;
      onChanged: (callback: (settings: Settings) => void) => void;
    };
  }
}

const hotkeyInput = document.getElementById('hotkey') as HTMLInputElement;
const showConfirmationInput = document.getElementById('showConfirmation') as HTMLInputElement;
const launchAtLoginInput = document.getElementById('launchAtLogin') as HTMLInputElement;
const debugModeInput = document.getElementById('debugMode') as HTMLInputElement;
const autoPasteInput = document.getElementById('autoPaste') as HTMLInputElement;
const saveButton = document.getElementById('save') as HTMLButtonElement;
const status = document.getElementById('status') as HTMLParagraphElement;

function render(settings: Settings): void {
  hotkeyInput.value = settings.hotkey;
  showConfirmationInput.checked = settings.showConfirmation;
  launchAtLoginInput.checked = settings.launchAtLogin;
  debugModeInput.checked = settings.debugMode;
  autoPasteInput.checked = settings.autoPaste;
}

async function bootstrap(): Promise<void> {
  const settings = await window.settingsApi.get();
  render(settings);

  saveButton.addEventListener('click', async () => {
    const next = await window.settingsApi.update({
      hotkey: hotkeyInput.value.trim(),
      showConfirmation: showConfirmationInput.checked,
      launchAtLogin: launchAtLoginInput.checked,
      debugMode: debugModeInput.checked,
      autoPaste: autoPasteInput.checked
    });
    render(next);
    status.textContent = 'Saved';
    setTimeout(() => {
      status.textContent = '';
    }, 1200);
  });

  window.settingsApi.onChanged(render);
}

void bootstrap();
