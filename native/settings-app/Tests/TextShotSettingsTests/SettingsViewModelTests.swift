import XCTest
@testable import TextShotSettings

private struct StubShortcutAvailabilityChecker: ShortcutAvailabilityChecking {
    let result: ShortcutAvailabilityResult

    func availability(for accelerator: String) -> ShortcutAvailabilityResult {
        _ = accelerator
        return result
    }
}

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testRecordingShortcutSavesImmediatelyWhenAvailable() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("settings.json")
        let defaultsData = try JSONEncoder().encode(PersistedSettings.defaults)
        try defaultsData.write(to: fileURL)

        let viewModel = SettingsViewModel(
            settingsURL: fileURL,
            shortcutAvailabilityChecker: StubShortcutAvailabilityChecker(result: .available)
        )
        viewModel.isRecording = true

        viewModel.onCapturedShortcut("Control+Alt+K")

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.settings.hotkey, "Control+Alt+K")
        XCTAssertEqual(viewModel.statusMessage, "Shortcut updated")
        XCTAssertEqual(viewModel.errorMessage, "")

        let saved = try SettingsFileStore(fileURL: fileURL).load()
        XCTAssertEqual(saved.hotkey, "Control+Alt+K")
    }

    func testRecordingShortcutRejectsInvalidAvailabilityAndKeepsOldShortcut() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("settings.json")
        let defaultsData = try JSONEncoder().encode(PersistedSettings.defaults)
        try defaultsData.write(to: fileURL)

        let viewModel = SettingsViewModel(
            settingsURL: fileURL,
            shortcutAvailabilityChecker: StubShortcutAvailabilityChecker(
                result: .unavailable("Shortcut is already in use by another app.")
            )
        )
        viewModel.isRecording = true

        viewModel.onCapturedShortcut("Control+Alt+K")

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.settings.hotkey, PersistedSettings.defaults.hotkey)
        XCTAssertEqual(viewModel.errorMessage, "Shortcut is already in use by another app.")
        XCTAssertEqual(viewModel.statusMessage, "")

        let saved = try SettingsFileStore(fileURL: fileURL).load()
        XCTAssertEqual(saved.hotkey, PersistedSettings.defaults.hotkey)
    }
}
