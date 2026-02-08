import SwiftUI

enum SettingsActionError: Error {
    case message(String)
}

extension SettingsActionError {
    var displayMessage: String {
        switch self {
        case .message(let message):
            return message
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: EditableSettings
    @Published var isRecording = false
    @Published var statusMessage = ""
    @Published var errorMessage = ""

    private let onSave: (EditableSettings) -> Result<EditableSettings, SettingsActionError>
    private let onApplyHotkey: (String) -> Result<String, SettingsActionError>
    private let onResetHotkey: () -> Result<String, SettingsActionError>

    init(
        initialSettings: EditableSettings,
        onSave: @escaping (EditableSettings) -> Result<EditableSettings, SettingsActionError>,
        onApplyHotkey: @escaping (String) -> Result<String, SettingsActionError>,
        onResetHotkey: @escaping () -> Result<String, SettingsActionError>
    ) {
        self.settings = initialSettings
        self.onSave = onSave
        self.onApplyHotkey = onApplyHotkey
        self.onResetHotkey = onResetHotkey
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
        switch onApplyHotkey(accelerator) {
        case .success(let active):
            settings.hotkey = active
            statusMessage = "Shortcut updated"
            errorMessage = ""
        case .failure(let error):
            errorMessage = error.displayMessage
            statusMessage = ""
        }

        isRecording = false
    }

    func onInvalidShortcutInput() {
        errorMessage = "Unsupported shortcut. Use one or more modifiers, or an F-key."
        statusMessage = ""
        isRecording = false
    }

    func save() {
        switch onSave(settings) {
        case .success(let persisted):
            settings = persisted
            statusMessage = "Saved"
            errorMessage = ""
        case .failure(let error):
            errorMessage = error.displayMessage
            statusMessage = ""
        }
    }

    func resetHotkeyToDefault() {
        switch onResetHotkey() {
        case .success(let active):
            settings.hotkey = active
            statusMessage = "Default shortcut restored"
            errorMessage = ""
        case .failure(let error):
            errorMessage = error.displayMessage
            statusMessage = ""
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Text Shot Settings")
                .font(.title3.weight(.semibold))

            GroupBox("Global Hotkey") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(model.settings.hotkey)
                            .font(.body.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                        Button(model.isRecording ? "Recording..." : "Record") {
                            if model.isRecording {
                                model.endShortcutRecording()
                            } else {
                                model.beginShortcutRecording()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Reset") {
                            model.resetHotkeyToDefault()
                        }
                        .buttonStyle(.bordered)
                    }

                    if model.isRecording {
                        ShortcutRecorder {
                            model.onCapturedShortcut($0)
                        } onInvalid: {
                            model.onInvalidShortcutInput()
                        }
                        .frame(height: 24)

                        Text("Press your shortcut now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Behavior") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Show confirmation pulse", isOn: $model.settings.showConfirmation)
                    Toggle("Launch at login", isOn: $model.settings.launchAtLogin)
                    Toggle("Auto-paste after copy (Accessibility required)", isOn: $model.settings.autoPaste)
                }
                .padding(.top, 4)
            }

            HStack {
                Button("Save") {
                    model.save()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }

            if !model.errorMessage.isEmpty {
                Text(model.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(minWidth: 500, minHeight: 320)
    }
}
