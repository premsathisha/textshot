import AppKit
import Foundation

@MainActor
final class AppRelocator {
    func promptToMoveIfNeeded() {
        guard shouldPromptForMove() else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Move Text Shot to Applications?"
        alert.informativeText = "Installing Text Shot in Applications keeps it available after updates and prevents running from a temporary location."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Keep Here")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        moveAndRelaunch()
    }

    private func shouldPromptForMove() -> Bool {
        let bundleURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let path = bundleURL.path

        if path.hasPrefix("/Applications/") {
            return false
        }

        let userApplications = NSHomeDirectory() + "/Applications/"
        if path.hasPrefix(userApplications) {
            return false
        }

        return Bundle.main.bundlePath.hasSuffix(".app")
    }

    private func moveAndRelaunch() {
        let fm = FileManager.default
        let sourceURL = Bundle.main.bundleURL
        let destinationURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(sourceURL.lastPathComponent)

        do {
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.trashItem(at: destinationURL, resultingItemURL: nil)
            }

            try fm.copyItem(at: sourceURL, to: destinationURL)

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: destinationURL, configuration: config) { _, _ in
                NSApp.terminate(nil)
            }
        } catch {
            let errorAlert = NSAlert()
            errorAlert.alertStyle = .warning
            errorAlert.messageText = "Could not move Text Shot"
            errorAlert.informativeText = error.localizedDescription
            errorAlert.runModal()
        }
    }
}
