import AppKit
import Darwin
import SwiftUI

private enum Bootstrap {
    static func settingsURL() -> URL {
        do {
            return try SettingsArguments.settingsFileURL(from: CommandLine.arguments)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(2)
        }
    }
}

final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    private var refocusSignalSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGUSR1, SIG_IGN)
        let signalSource = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        signalSource.setEventHandler { [weak self] in
            self?.activateSettingsWindow()
        }
        signalSource.resume()
        refocusSignalSource = signalSource

        activateSettingsWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        activateSettingsWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        refocusSignalSource?.cancel()
        refocusSignalSource = nil
    }

    private func activateSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)

        let window = NSApp.keyWindow ?? NSApp.windows.first
        guard let window else { return }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

@main
struct TextShotSettingsApp: App {
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) private var appDelegate
    @StateObject private var model = SettingsViewModel(settingsURL: Bootstrap.settingsURL())

    var body: some Scene {
        WindowGroup("Text Shot Settings") {
            ContentView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}
