import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppController {
    private let settingsStore: SettingsStoreV2
    private let hotkeyManager: HotkeyManaging
    private let shortcutAvailabilityChecker = ShortcutAvailabilityChecker()
    private let captureService: CaptureServing
    private let ocrService: OCRServing
    private let clipboardService: ClipboardWriting
    private let autoPasteService: AutoPasting
    private let permissionPrompts: PermissionPrompting
    private let launchAtLoginService: LaunchAtLoginApplying
    private let toastPresenter: ToastPresenting
    private let screenCapturePermissionService: ScreenCapturePermissionChecking

    private var settingsWindowController: NSWindowController?
    private var currentSettings: AppSettingsV2
    private var lastCopiedText = ""
    private var isCaptureInFlight = false

    init(
        settingsStore: SettingsStoreV2,
        hotkeyManager: HotkeyManaging = HotkeyManager(),
        captureService: CaptureServing = CaptureService(),
        ocrService: OCRServing = OCRService(),
        clipboardService: ClipboardWriting = ClipboardService(),
        autoPasteService: AutoPasting = AutoPasteService(),
        permissionPrompts: PermissionPrompting = PermissionPromptService(),
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
        self.autoPasteService = autoPasteService
        self.permissionPrompts = permissionPrompts
        self.launchAtLoginService = launchAtLoginService
        self.toastPresenter = toastPresenter ?? ToastPresenter()
        self.screenCapturePermissionService = screenCapturePermissionService
        self.currentSettings = settingsStore.load()

        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.runCaptureFlow()
            }
        }

        if installStartupStateOnInit {
            installStartupState()
        }
    }

    func openSettings() {
        let model = SettingsViewModel(
            initialSettings: currentSettings.editable,
            onSave: { [weak self] editable in
                guard let self else { return .failure(.message("Settings unavailable")) }
                return self.saveSettings(editable)
            },
            onApplyHotkey: { [weak self] hotkey in
                guard let self else { return .failure(.message("Settings unavailable")) }
                return self.applyHotkeyFromSettings(hotkey)
            },
            onResetHotkey: { [weak self] in
                guard let self else { return .failure(.message("Settings unavailable")) }
                return self.applyHotkeyFromSettings(AppSettingsV2.defaults.hotkey)
            }
        )

        let contentView = SettingsView().environmentObject(model)
        let hosting = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Text Shot Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 340))
        window.center()

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

    private func installStartupState() {
        launchAtLoginService.apply(enabled: currentSettings.launchAtLogin)

        do {
            _ = try hotkeyManager.apply(accelerator: currentSettings.hotkey)
        } catch {
            // Startup fallback only if there is no active hotkey yet.
            if (try? hotkeyManager.apply(accelerator: AppSettingsV2.defaults.hotkey)) != nil {
                currentSettings.hotkey = AppSettingsV2.defaults.hotkey
                _ = try? settingsStore.save(currentSettings)
            }
        }
    }

    private func applyHotkeyFromSettings(_ hotkey: String) -> Result<String, SettingsActionError> {
        switch shortcutAvailabilityChecker.availability(for: hotkey) {
        case .available:
            do {
                let normalized = try hotkeyManager.apply(accelerator: hotkey)
                currentSettings.hotkey = normalized
                _ = try settingsStore.save(currentSettings)
                return .success(normalized)
            } catch {
                return .failure(.message(error.localizedDescription))
            }

        case .unavailable(let message):
            return .failure(.message(message))
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

    private func shouldThrottlePermissionPrompt(lastAt: Int) -> Bool {
        permissionPrompts.shouldThrottle(lastShownAt: lastAt)
    }

    private func updatePermissionTimestamp(screenRecording: Bool) {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        if screenRecording {
            currentSettings.lastPermissionPromptAt = now
        } else {
            currentSettings.lastAccessibilityPromptAt = now
        }
        _ = try? settingsStore.save(currentSettings)
    }

    private func showToastIfEnabled(_ message: String) {
        if currentSettings.showConfirmation {
            toastPresenter.show(message)
        }
    }

    private func shouldSuggestMoveToApplications() -> Bool {
        let bundleURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let path = bundleURL.path

        if path.hasPrefix("/Applications/") {
            return false
        }

        let userApplications = NSHomeDirectory() + "/Applications/"
        if path.hasPrefix(userApplications) {
            return false
        }

        return true
    }

    private func showScreenRecordingPromptIfNeeded() {
        guard !shouldThrottlePermissionPrompt(lastAt: currentSettings.lastPermissionPromptAt) else {
            return
        }

        updatePermissionTimestamp(screenRecording: true)
        permissionPrompts.showScreenRecordingPrompt(includeMoveToApplicationsHint: shouldSuggestMoveToApplications())
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
            try? FileManager.default.removeItem(atPath: path)
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

            if currentSettings.autoPaste {
                let pasted = autoPasteService.paste()
                if !pasted && !shouldThrottlePermissionPrompt(lastAt: currentSettings.lastAccessibilityPromptAt) {
                    updatePermissionTimestamp(screenRecording: false)
                    permissionPrompts.showAccessibilityPrompt()
                }
            }

            showToastIfEnabled("Copied!")
        } catch {
            showToastIfEnabled("Error")
        }
    }
}
