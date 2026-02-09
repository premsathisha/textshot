import SwiftUI
import KeyboardShortcuts

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
    @Published private(set) var settings: EditableSettings
    @Published var errorMessage = ""
    @Published var warningMessage = ""
    @Published var recorderShortcut: AppHotkeyShortcut?

    let hotkeyController: any HotkeyManaging & HotkeyRecorderBindingProviding

    private let onApplySettings: (EditableSettings) -> Result<EditableSettings, SettingsActionError>

    init(
        initialSettings: EditableSettings,
        hotkeyController: any HotkeyManaging & HotkeyRecorderBindingProviding,
        onApplySettings: @escaping (EditableSettings) -> Result<EditableSettings, SettingsActionError>
    ) {
        self.settings = initialSettings
        self.hotkeyController = hotkeyController
        self.onApplySettings = onApplySettings
        self.recorderShortcut = hotkeyController.activeShortcut

        if let shortcut = hotkeyController.activeShortcut {
            var updated = settings
            updated.hotkey = HotkeyManager.displayString(for: shortcut)
            settings = updated
        }
    }

    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { self.settings.launchAtLogin },
            set: { self.updateSetting { $0.launchAtLogin = $1 }($0) }
        )
    }

    var showConfirmationBinding: Binding<Bool> {
        Binding(
            get: { self.settings.showConfirmation },
            set: { self.updateSetting { $0.showConfirmation = $1 }($0) }
        )
    }

    var recorderAvailabilityIssue: String? {
        hotkeyController.recorderAvailabilityIssue
    }

    func onRecorderError(_ message: String) {
        errorMessage = message
    }

    func onRecorderWarning(_ message: String?) {
        warningMessage = message ?? ""
    }

    func syncHotkeyDisplay(with shortcut: AppHotkeyShortcut?) {
        recorderShortcut = shortcut

        var updated = settings
        updated.hotkey = HotkeyManager.displayString(for: shortcut)
        settings = updated
    }

    private func updateSetting(_ transform: @escaping (inout EditableSettings, Bool) -> Void) -> (Bool) -> Void {
        { [weak self] value in
            guard let self else {
                return
            }

            let previous = self.settings
            var next = previous
            transform(&next, value)

            switch self.onApplySettings(next) {
            case .success(let persisted):
                self.settings = persisted
                self.errorMessage = ""

            case .failure(let error):
                self.settings = previous
                self.errorMessage = error.displayMessage
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: SettingsViewModel

    private let labelColumnWidth: CGFloat = 170
    private let controlColumnWidth: CGFloat = 178

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            hotkeyRow

            toggleRow(
                title: "Launch At Login",
                isOn: model.launchAtLoginBinding
            )

            toggleRow(
                title: "show confirmation pulse.",
                isOn: model.showConfirmationBinding
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(width: 420, height: 270, alignment: .topLeading)
    }

    private var hotkeyRow: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Global Hotkey")
                    .font(.system(size: 13))
            }
            .frame(width: labelColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                if let issue = model.recorderAvailabilityIssue {
                    Text(issue)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(width: controlColumnWidth, alignment: .leading)
                } else {
                    KeyboardShortcutField(
                        hotkeyController: model.hotkeyController,
                        shortcut: $model.recorderShortcut,
                        onError: { model.onRecorderError($0) },
                        onWarning: { model.onRecorderWarning($0) }
                    )
                    .frame(width: controlColumnWidth, height: 32, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                Color(nsColor: .separatorColor),
                                lineWidth: 1
                            )
                    )
                }

                if !model.errorMessage.isEmpty {
                    Text(model.errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .frame(width: controlColumnWidth, alignment: .leading)
                }

                if !model.warningMessage.isEmpty {
                    Text(model.warningMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .frame(width: controlColumnWidth, alignment: .leading)
                }
            }
            .frame(width: controlColumnWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 24) {
            Text(title)
                .font(.system(size: 13))
            .frame(width: labelColumnWidth, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(width: controlColumnWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
