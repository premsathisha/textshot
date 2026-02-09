import AppKit
import Foundation
import ShortcutRecorder
import Testing
@testable import TextShotSettings

private final class MockHotkeyController: HotkeyManaging, HotkeyRecorderBindingProviding {
    var onHotkeyPressed: (() -> Void)?
    var onShortcutChanged: ((Shortcut) -> Void)?
    var activeShortcut: Shortcut?
    var applyError: Error?
    var resetError: Error?

    let defaultsController: NSUserDefaultsController = .shared
    let defaultsKeyPath = HotkeyManager.defaultsKeyPath
    let bindingOptions: [NSBindingOption: Any] = [
        .valueTransformerName: NSValueTransformerName.keyedUnarchiveFromDataTransformerName
    ]
    var recorderAvailabilityIssue: String?

    init() {}

    @discardableResult
    func apply(shortcut: Shortcut) throws -> Shortcut {
        if let applyError {
            throw applyError
        }

        activeShortcut = shortcut
        onShortcutChanged?(shortcut)
        return shortcut
    }

    @discardableResult
    func resetToDefault() throws -> Shortcut {
        if let resetError {
            throw resetError
        }

        activeShortcut = HotkeyManager.defaultShortcut
        onShortcutChanged?(HotkeyManager.defaultShortcut)
        return HotkeyManager.defaultShortcut
    }

    func validateForRecorder(_ shortcut: Shortcut) throws {
        if let applyError {
            throw applyError
        }
        try HotkeyManager.validateNoModifierRule(shortcut)
    }
}

private final class MockCaptureService: CaptureServing {
    var result: CaptureResult
    private(set) var callCount = 0

    init(result: CaptureResult) {
        self.result = result
    }

    func captureRegion() async -> CaptureResult {
        callCount += 1
        return result
    }
}

private final class MockOCRService: OCRServing {
    var text: String?
    var thrownError: Error?

    init(text: String?, thrownError: Error? = nil) {
        self.text = text
        self.thrownError = thrownError
    }

    func runOcrWithRetry(imagePath: String) throws -> String? {
        if let thrownError {
            throw thrownError
        }
        return text
    }
}

private final class MockClipboardService: ClipboardWriting {
    private(set) var writes: [String] = []

    func write(_ text: String) {
        writes.append(text)
    }
}

private final class MockLaunchAtLoginService: LaunchAtLoginApplying {
    private(set) var appliedValues: [Bool] = []

    func apply(enabled: Bool) {
        appliedValues.append(enabled)
    }
}

@MainActor
private final class MockToastPresenter: ToastPresenting {
    private(set) var messages: [String] = []

    func show(_ message: String) {
        messages.append(message)
    }
}

private final class MockScreenCapturePermissionService: ScreenCapturePermissionChecking {
    var preflightResult: Bool
    var requestResult: Bool
    private(set) var requestCount = 0

    init(preflightResult: Bool, requestResult: Bool) {
        self.preflightResult = preflightResult
        self.requestResult = requestResult
    }

    func preflightAuthorized() -> Bool {
        preflightResult
    }

    func requestIfNeededOncePerLaunch() -> Bool {
        requestCount += 1
        return requestResult
    }
}

private func makeSettingsStore() throws -> (SettingsStoreV2, URL) {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let fileURL = tempDir.appendingPathComponent("settings-v3.json")
    return (SettingsStoreV2(fileURL: fileURL), tempDir)
}

@MainActor
@Test
func appControllerDeniedPreflightSkipsCapture() async throws {
    let (store, tempDir) = try makeSettingsStore()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let hotkeys = MockHotkeyController()
    let capture = MockCaptureService(
        result: CaptureResult(canceled: false, path: nil, error: "unexpected", failureReason: .unexpected(message: "unexpected"))
    )
    let ocr = MockOCRService(text: nil)
    let clipboard = MockClipboardService()
    let launch = MockLaunchAtLoginService()
    let toast = MockToastPresenter()
    let screenPerms = MockScreenCapturePermissionService(preflightResult: false, requestResult: false)

    let controller = AppController(
        settingsStore: store,
        hotkeyManager: hotkeys,
        captureService: capture,
        ocrService: ocr,
        clipboardService: clipboard,
        launchAtLoginService: launch,
        toastPresenter: toast,
        screenCapturePermissionService: screenPerms,
        installStartupStateOnInit: false
    )

    await controller.runCaptureFlow()

    #expect(screenPerms.requestCount == 1)
    #expect(capture.callCount == 0)
    #expect(toast.messages.isEmpty)
}

@MainActor
@Test
func appControllerCaptureToolFailureShowsCaptureFailedToast() async throws {
    let (store, tempDir) = try makeSettingsStore()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let hotkeys = MockHotkeyController()
    let capture = MockCaptureService(
        result: CaptureResult(
            canceled: false,
            path: nil,
            error: "screencapture failed",
            failureReason: .toolFailed(message: "screencapture failed")
        )
    )
    let ocr = MockOCRService(text: nil)
    let clipboard = MockClipboardService()
    let launch = MockLaunchAtLoginService()
    let toast = MockToastPresenter()
    let screenPerms = MockScreenCapturePermissionService(preflightResult: true, requestResult: true)

    let controller = AppController(
        settingsStore: store,
        hotkeyManager: hotkeys,
        captureService: capture,
        ocrService: ocr,
        clipboardService: clipboard,
        launchAtLoginService: launch,
        toastPresenter: toast,
        screenCapturePermissionService: screenPerms,
        installStartupStateOnInit: false
    )

    await controller.runCaptureFlow()

    #expect(toast.messages == ["Capture failed"])
}

@MainActor
@Test
func appControllerAuthorizedCaptureCopiesTextAndShowsCopiedToast() async throws {
    let (store, tempDir) = try makeSettingsStore()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let tempImage = tempDir.appendingPathComponent("capture.png")
    try Data("stub".utf8).write(to: tempImage)

    let hotkeys = MockHotkeyController()
    let capture = MockCaptureService(
        result: CaptureResult(
            canceled: false,
            path: tempImage.path,
            error: nil,
            failureReason: nil
        )
    )
    let ocr = MockOCRService(text: "Copied text")
    let clipboard = MockClipboardService()
    let launch = MockLaunchAtLoginService()
    let toast = MockToastPresenter()
    let screenPerms = MockScreenCapturePermissionService(preflightResult: true, requestResult: true)

    let controller = AppController(
        settingsStore: store,
        hotkeyManager: hotkeys,
        captureService: capture,
        ocrService: ocr,
        clipboardService: clipboard,
        launchAtLoginService: launch,
        toastPresenter: toast,
        screenCapturePermissionService: screenPerms,
        installStartupStateOnInit: false
    )

    await controller.runCaptureFlow()

    #expect(clipboard.writes == ["Copied text"])
    #expect(toast.messages == ["Copied!"])
    #expect(FileManager.default.fileExists(atPath: tempImage.path) == false)
}

@MainActor
@Test
func appControllerApplyShortcutReturnsErrorMessage() throws {
    let (store, tempDir) = try makeSettingsStore()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let hotkeys = MockHotkeyController()
    hotkeys.activeShortcut = HotkeyManager.defaultShortcut
    hotkeys.applyError = HotkeyApplyError.conflict(message: "Shortcut is already in use.")

    let capture = MockCaptureService(
        result: CaptureResult(canceled: true, path: nil, error: nil, failureReason: nil)
    )
    let ocr = MockOCRService(text: nil)
    let clipboard = MockClipboardService()
    let launch = MockLaunchAtLoginService()
    let toast = MockToastPresenter()
    let screenPerms = MockScreenCapturePermissionService(preflightResult: true, requestResult: true)

    let controller = AppController(
        settingsStore: store,
        hotkeyManager: hotkeys,
        captureService: capture,
        ocrService: ocr,
        clipboardService: clipboard,
        launchAtLoginService: launch,
        toastPresenter: toast,
        screenCapturePermissionService: screenPerms,
        installStartupStateOnInit: false
    )

    let requested = Shortcut(keyEquivalent: "⌃⌥K")!
    let result = controller.applyShortcutForTesting(requested)

    switch result {
    case .success:
        Issue.record("Expected failure for apply error")
    case .failure(let error):
        #expect(error.displayMessage == "Shortcut is already in use.")
    }

    #expect(toast.messages.isEmpty)
    #expect(hotkeys.activeShortcut?.isEqual(HotkeyManager.defaultShortcut) == true)
}
