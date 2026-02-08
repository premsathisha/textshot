import Foundation
import Testing
@testable import TextShotSettings

private final class MockHotkeyManager: HotkeyManaging {
    var onHotkeyPressed: (() -> Void)?

    @discardableResult
    func apply(accelerator: String) throws -> String {
        accelerator
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

private final class MockAutoPasteService: AutoPasting {
    var shouldSucceed = true

    func paste() -> Bool {
        shouldSucceed
    }
}

private final class MockPermissionPrompts: PermissionPrompting {
    var throttleResult = false
    private(set) var screenPromptCount = 0
    private(set) var accessibilityPromptCount = 0
    private(set) var moveHintValues: [Bool] = []

    func shouldThrottle(lastShownAt: Int) -> Bool {
        throttleResult
    }

    func showScreenRecordingPrompt(includeMoveToApplicationsHint: Bool) {
        screenPromptCount += 1
        moveHintValues.append(includeMoveToApplicationsHint)
    }

    func showAccessibilityPrompt() {
        accessibilityPromptCount += 1
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
    let fileURL = tempDir.appendingPathComponent("settings-v2.json")
    return (SettingsStoreV2(fileURL: fileURL), tempDir)
}

@MainActor
@Test
func appControllerDeniedPreflightShowsScreenPromptWithoutCapture() async throws {
    let (store, tempDir) = try makeSettingsStore()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let hotkeys = MockHotkeyManager()
    let capture = MockCaptureService(
        result: CaptureResult(canceled: false, path: nil, error: "unexpected", failureReason: .unexpected(message: "unexpected"))
    )
    let ocr = MockOCRService(text: nil)
    let clipboard = MockClipboardService()
    let autoPaste = MockAutoPasteService()
    let prompts = MockPermissionPrompts()
    let launch = MockLaunchAtLoginService()
    let toast = MockToastPresenter()
    let screenPerms = MockScreenCapturePermissionService(preflightResult: false, requestResult: false)

    let controller = AppController(
        settingsStore: store,
        hotkeyManager: hotkeys,
        captureService: capture,
        ocrService: ocr,
        clipboardService: clipboard,
        autoPasteService: autoPaste,
        permissionPrompts: prompts,
        launchAtLoginService: launch,
        toastPresenter: toast,
        screenCapturePermissionService: screenPerms,
        installStartupStateOnInit: false
    )

    await controller.runCaptureFlow()

    #expect(screenPerms.requestCount == 1)
    #expect(capture.callCount == 0)
    #expect(prompts.screenPromptCount == 1)
    #expect(toast.messages.isEmpty)
}

@MainActor
@Test
func appControllerCaptureToolFailureDoesNotShowScreenPrompt() async throws {
    let (store, tempDir) = try makeSettingsStore()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let hotkeys = MockHotkeyManager()
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
    let autoPaste = MockAutoPasteService()
    let prompts = MockPermissionPrompts()
    let launch = MockLaunchAtLoginService()
    let toast = MockToastPresenter()
    let screenPerms = MockScreenCapturePermissionService(preflightResult: true, requestResult: true)

    let controller = AppController(
        settingsStore: store,
        hotkeyManager: hotkeys,
        captureService: capture,
        ocrService: ocr,
        clipboardService: clipboard,
        autoPasteService: autoPaste,
        permissionPrompts: prompts,
        launchAtLoginService: launch,
        toastPresenter: toast,
        screenCapturePermissionService: screenPerms,
        installStartupStateOnInit: false
    )

    await controller.runCaptureFlow()

    #expect(prompts.screenPromptCount == 0)
    #expect(toast.messages == ["Capture failed"])
}

@MainActor
@Test
func appControllerAuthorizedCaptureCopiesTextAndShowsCopiedToast() async throws {
    let (store, tempDir) = try makeSettingsStore()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let tempImage = tempDir.appendingPathComponent("capture.png")
    try Data("stub".utf8).write(to: tempImage)

    let hotkeys = MockHotkeyManager()
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
    let autoPaste = MockAutoPasteService()
    let prompts = MockPermissionPrompts()
    let launch = MockLaunchAtLoginService()
    let toast = MockToastPresenter()
    let screenPerms = MockScreenCapturePermissionService(preflightResult: true, requestResult: true)

    let controller = AppController(
        settingsStore: store,
        hotkeyManager: hotkeys,
        captureService: capture,
        ocrService: ocr,
        clipboardService: clipboard,
        autoPasteService: autoPaste,
        permissionPrompts: prompts,
        launchAtLoginService: launch,
        toastPresenter: toast,
        screenCapturePermissionService: screenPerms,
        installStartupStateOnInit: false
    )

    await controller.runCaptureFlow()

    #expect(clipboard.writes == ["Copied text"])
    #expect(toast.messages == ["Copied!"])
    #expect(prompts.screenPromptCount == 0)
    #expect(FileManager.default.fileExists(atPath: tempImage.path) == false)
}
