import Foundation
import Testing
@testable import TextShotSettings

@Test
func settingsMigratorImportsLegacyJsonIntoV2() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let legacyDir = tempDir.appendingPathComponent("Text Shot", isDirectory: true)
    try FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)

    let legacyPath = legacyDir.appendingPathComponent("settings.json")
    let legacyPayload: [String: Any] = [
        "hotkey": "Control+Alt+K",
        "showConfirmation": false,
        "launchAtLogin": true,
        "autoPaste": true,
        "lastPermissionPromptAt": 10,
        "lastAccessibilityPromptAt": 20,
        "debugMode": true
    ]

    let data = try JSONSerialization.data(withJSONObject: legacyPayload, options: [])
    try data.write(to: legacyPath)

    let migrator = SettingsMigrator(fileManager: .default, appSupportURLOverride: tempDir)
    let store = try migrator.prepareStore()
    let loaded = store.load()

    #expect(loaded.hotkey == "Control+Alt+K")
    #expect(loaded.showConfirmation == false)
    #expect(loaded.launchAtLogin)
    #expect(loaded.autoPaste)
    #expect(loaded.lastPermissionPromptAt == 10)
    #expect(loaded.lastAccessibilityPromptAt == 20)
    #expect(loaded.schemaVersion == 2)

    #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Text Shot/.migration-v2-done").path))
    #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Text Shot/settings-v2.json").path))
}
