import XCTest
@testable import TextShotSettings

final class SettingsFileStoreTests: XCTestCase {
    func testSaveRoundTripAndMetadataPreservation() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("settings.json")
        let initial = PersistedSettings(
            hotkey: "CommandOrControl+Shift+2",
            showConfirmation: true,
            launchAtLogin: false,
            debugMode: false,
            autoPaste: false,
            lastPermissionPromptAt: 123,
            lastAccessibilityPromptAt: 456
        )

        let initialData = try JSONEncoder().encode(initial)
        try initialData.write(to: fileURL)

        let store = SettingsFileStore(fileURL: fileURL)
        let loaded = try store.load()

        let edited = EditableSettings(
            hotkey: "Control+Alt+K",
            showConfirmation: false,
            launchAtLogin: true,
            debugMode: true,
            autoPaste: true
        )

        let saved = try store.save(editable: edited, preserving: loaded)

        XCTAssertEqual(saved.hotkey, "Control+Alt+K")
        XCTAssertEqual(saved.showConfirmation, false)
        XCTAssertEqual(saved.launchAtLogin, true)
        XCTAssertEqual(saved.debugMode, true)
        XCTAssertEqual(saved.autoPaste, true)
        XCTAssertEqual(saved.lastPermissionPromptAt, 123)
        XCTAssertEqual(saved.lastAccessibilityPromptAt, 456)

        let reread = try store.load()
        XCTAssertEqual(reread, saved)
    }
}
