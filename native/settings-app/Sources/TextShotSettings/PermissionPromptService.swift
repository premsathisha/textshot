import AppKit
import Foundation

protocol PermissionPrompting {
    func shouldThrottle(lastShownAt: Int) -> Bool
    func showScreenRecordingPrompt(includeMoveToApplicationsHint: Bool)
    func showAccessibilityPrompt()
}

final class PermissionPromptService {
    private let throttleWindowMs = 30_000

    func shouldThrottle(lastShownAt: Int) -> Bool {
        Int(Date().timeIntervalSince1970 * 1000) - lastShownAt < throttleWindowMs
    }

    func showScreenRecordingPrompt(includeMoveToApplicationsHint: Bool = false) {
        var detail = "System Settings -> Privacy & Security -> Screen Recording"
        if includeMoveToApplicationsHint {
            detail += "\n\nMove Text Shot to Applications for reliable permission persistence."
        }

        showPrompt(
            title: "Screen Recording Required",
            message: "Enable Screen Recording to use Text Shot.",
            detail: detail,
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        )
    }

    func showAccessibilityPrompt() {
        showPrompt(
            title: "Accessibility Required",
            message: "Enable Accessibility to allow auto-paste.",
            detail: "System Settings -> Privacy & Security -> Accessibility",
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    private func showPrompt(title: String, message: String, detail: String, settingsURL: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = title
            alert.informativeText = "\(message)\n\n\(detail)"
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Not now")

            let result = alert.runModal()
            guard result == .alertFirstButtonReturn else { return }
            if let url = URL(string: settingsURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

extension PermissionPromptService: PermissionPrompting {}
