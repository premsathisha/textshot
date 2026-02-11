import AppKit
import Foundation
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppController {
    private let settingsStore: SettingsStoreV2
    private let hotkeyManager: any HotkeyManaging & HotkeyRecorderBindingProviding
    private let captureService: CaptureServing
    private let ocrService: OCRServing
    private let clipboardService: ClipboardWriting
    private let launchAtLoginService: LaunchAtLoginApplying
    private let toastPresenter: ToastPresenting
    private let screenCapturePermissionService: ScreenCapturePermissionChecking

    private var settingsWindowController: NSWindowController?
    private var settingsViewModel: SettingsViewModel?
    private var currentSettings: AppSettingsV2
    private var lastCopiedText = ""
    private var isCaptureInFlight = false

    init(
        settingsStore: SettingsStoreV2,
        hotkeyManager: any HotkeyManaging & HotkeyRecorderBindingProviding = HotkeyBindingController(),
        captureService: CaptureServing = CaptureService(),
        ocrService: OCRServing = OCRService(),
        clipboardService: ClipboardWriting = ClipboardService(),
        launchAtLoginService: LaunchAtLoginApplying = LaunchAtLoginService(),
        toastPresenter: ToastPresenting? = nil,
        screenCapturePermissionService: ScreenCapturePermissionChecking = ScreenCapturePermissionService(),
        installStartupStateOnInit: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.hotkeyManager = hotkeyManager
        self.captureService = captureService
        self.ocrService = ocrService
        self.clipboardService = clipboardService
        self.launchAtLoginService = launchAtLoginService
        self.toastPresenter = toastPresenter ?? ToastPresenter()
        self.screenCapturePermissionService = screenCapturePermissionService
        self.currentSettings = settingsStore.load()

        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.runCaptureFlow()
            }
        }

        hotkeyManager.onShortcutChanged = { [weak self] shortcut in
            Task { @MainActor [weak self] in
                self?.syncHotkeyMirror(to: shortcut)
                self?.settingsViewModel?.syncHotkeyDisplay(with: shortcut)
            }
        }

        if installStartupStateOnInit {
            installStartupState()
        }
    }

    func openSettings() {
        if let existingWindow = settingsWindowController?.window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let model = SettingsViewModel(
            initialSettings: currentSettings.editable,
            hotkeyController: hotkeyManager,
            onApplySettings: { [weak self] editable in
                guard let self else { return .failure(.message("Settings unavailable")) }
                return self.saveSettings(editable)
            }
        )
        settingsViewModel = model

        let contentView = SettingsView().environmentObject(model)
        let hosting = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 360, height: 188))
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func captureNow() {
        Task { @MainActor in
            await runCaptureFlow()
        }
    }

    @discardableResult
    func applyShortcutForTesting(_ shortcut: AppHotkeyShortcut?) -> Result<AppHotkeyShortcut?, SettingsActionError> {
        applyHotkeyFromSettings(shortcut)
    }

    private func installStartupState() {
        launchAtLoginService.apply(enabled: currentSettings.launchAtLogin)

        if case .none = hotkeyManager.activeShortcut {
            _ = try? hotkeyManager.resetToDefault()
        }

        syncHotkeyMirrorToActiveShortcut()
    }

    private func activeShortcutOrDefault() -> AppHotkeyShortcut {
        hotkeyManager.activeShortcut ?? HotkeyManager.defaultShortcut
    }

    private func syncHotkeyMirrorToActiveShortcut() {
        syncHotkeyMirror(to: activeShortcutOrDefault())
    }

    private func syncHotkeyMirror(to shortcut: AppHotkeyShortcut?) {
        let display = HotkeyManager.displayString(for: shortcut)
        if currentSettings.hotkey == display {
            return
        }

        currentSettings.hotkey = display
        _ = try? settingsStore.save(currentSettings)
    }

    private func applyHotkeyFromSettings(_ shortcut: AppHotkeyShortcut?) -> Result<AppHotkeyShortcut?, SettingsActionError> {
        do {
            let active = try hotkeyManager.apply(shortcut: shortcut)
            syncHotkeyMirror(to: active)
            return .success(active)
        } catch {
            return .failure(.message(error.localizedDescription))
        }
    }

    private func saveSettings(_ editable: EditableSettings) -> Result<EditableSettings, SettingsActionError> {
        var next = currentSettings
        next.apply(editable)

        do {
            currentSettings = try settingsStore.save(next)
            launchAtLoginService.apply(enabled: currentSettings.launchAtLogin)
            return .success(currentSettings.editable)
        } catch {
            return .failure(.message("Failed to save settings: \(error.localizedDescription)"))
        }
    }

    private func showToastIfEnabled(_ message: String) {
        if currentSettings.showConfirmation {
            toastPresenter.show(message)
        }
    }

    private func showScreenRecordingPromptIfNeeded() {
        // macOS already shows the system Screen Recording permission dialog.
    }

    func runCaptureFlow() async {
        guard !isCaptureInFlight else { return }
        isCaptureInFlight = true
        defer { isCaptureInFlight = false }

        let hasScreenCaptureAccess: Bool
        if screenCapturePermissionService.preflightAuthorized() {
            hasScreenCaptureAccess = true
        } else {
            hasScreenCaptureAccess = screenCapturePermissionService.requestIfNeededOncePerLaunch()
        }

        guard hasScreenCaptureAccess else {
            showScreenRecordingPromptIfNeeded()
            return
        }

        let capture = await captureService.captureRegion()
        if capture.canceled {
            return
        }

        guard let path = capture.path else {
            if capture.failureReason == .permissionDenied {
                showScreenRecordingPromptIfNeeded()
            } else {
                showToastIfEnabled("Capture failed")
            }
            return
        }

        defer {
            CaptureTempStore.shared.removeCaptureFile(atPath: path)
        }

        do {
            guard let text = try ocrService.runOcrWithRetry(imagePath: path), !text.isEmpty else {
                showToastIfEnabled("No text")
                return
            }

            if text == lastCopiedText {
                clipboardService.write(text)
                return
            }

            clipboardService.write(text)
            lastCopiedText = text
            showToastIfEnabled("Copied!")
        } catch {
            showToastIfEnabled("Error")
        }
    }
}
