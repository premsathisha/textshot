import AppKit
import SwiftUI

private enum Bootstrap {
    @MainActor
    static func appController() -> AppController {
        let migrator = SettingsMigrator()
        let store = (try? migrator.prepareStore()) ?? SettingsStoreV2(fileURL: fallbackSettingsURL())
        return AppController(settingsStore: store)
    }

    private static func fallbackSettingsURL() -> URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Text Shot", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("settings-v3.json")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = Bootstrap.appController()
    private let appRelocator = AppRelocator()
    private var statusItem: NSStatusItem?
    private var willTerminateObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CaptureTempStore.shared.prepareForLaunch()
        willTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in
            CaptureTempStore.shared.cleanupTrackedFiles()
        }
        setupStatusItem()
        appRelocator.promptToMoveIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "TS"

        let menu = NSMenu()
        menu.addItem(withTitle: "Capture Text", action: #selector(captureText), keyEquivalent: "")
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = nil
        settingsItem.onStateImage = nil
        settingsItem.offStateImage = nil
        settingsItem.mixedStateImage = nil
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")

        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func captureText() {
        controller.captureNow()
    }

    @objc private func openSettings() {
        controller.openSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

@main
struct TextShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
