import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: EditableSettings
    @Published var isRecording = false
    @Published var statusMessage = ""
    @Published var errorMessage = ""

    private let store: SettingsFileStore
    private let shortcutAvailabilityChecker: any ShortcutAvailabilityChecking
    private var persistedSettings: PersistedSettings

    init(
        settingsURL: URL,
        shortcutAvailabilityChecker: any ShortcutAvailabilityChecking = ShortcutAvailabilityChecker()
    ) {
        self.store = SettingsFileStore(fileURL: settingsURL)
        self.shortcutAvailabilityChecker = shortcutAvailabilityChecker

        if let loaded = try? store.load() {
            self.persistedSettings = loaded
        } else {
            self.persistedSettings = PersistedSettings.defaults
        }

        self.settings = persistedSettings.editable
    }

    func beginShortcutRecording() {
        errorMessage = ""
        statusMessage = ""
        isRecording = true
    }

    func endShortcutRecording() {
        isRecording = false
    }

    func onCapturedShortcut(_ accelerator: String) {
        let previousHotkey = settings.hotkey

        switch shortcutAvailabilityChecker.availability(for: accelerator) {
        case .available:
            settings.hotkey = accelerator
            if !save(statusMessageOnSuccess: "Shortcut updated") {
                settings.hotkey = previousHotkey
            }
        case .unavailable(let message):
            settings.hotkey = previousHotkey
            errorMessage = message
            statusMessage = ""
        }

        isRecording = false
    }

    func onInvalidShortcutInput() {
        errorMessage = "Unsupported shortcut. Use modifiers plus a letter, number, function, or navigation key."
        statusMessage = ""
        isRecording = false
    }

    @discardableResult
    func save(statusMessageOnSuccess: String = "Saved") -> Bool {
        if let validation = ShortcutCodec.validateAccelerator(settings.hotkey) {
            errorMessage = validation
            statusMessage = ""
            return false
        }

        do {
            persistedSettings = try store.save(editable: settings, preserving: persistedSettings)
            statusMessage = statusMessageOnSuccess
            errorMessage = ""
            return true
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            statusMessage = ""
            return false
        }
    }

    func resetToDefaults() {
        settings = PersistedSettings.defaults.editable
        statusMessage = "Defaults restored. Save to apply."
        errorMessage = ""
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Global Hotkey")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(model.settings.hotkey)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.gray.opacity(0.35), lineWidth: 1)
                        )

                    Button(model.isRecording ? "Recording..." : "Record") {
                        if model.isRecording {
                            model.endShortcutRecording()
                        } else {
                            model.beginShortcutRecording()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if model.isRecording {
                    ShortcutRecorder {
                        model.onCapturedShortcut($0)
                    } onInvalid: {
                        model.onInvalidShortcutInput()
                    }
                    .frame(height: 24)
                    Text("Press your shortcut now")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !model.errorMessage.isEmpty {
                    Text(model.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Toggle("Show confirmation pulse", isOn: $model.settings.showConfirmation)
            Toggle("Launch at login", isOn: $model.settings.launchAtLogin)
            Toggle("Debug mode (retain last capture)", isOn: $model.settings.debugMode)
            Toggle("Auto-paste after copy (Accessibility required)", isOn: $model.settings.autoPaste)

            HStack {
                Button("Reset to Defaults") {
                    model.resetToDefaults()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    model.save()
                }
                .buttonStyle(.borderedProminent)
            }

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 440)
    }
}
