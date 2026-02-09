import Foundation
import Testing
@testable import TextShotSettings

@Test
func settingsStoreRoundTripPreservesCurrentFields() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let fileURL = tempDir.appendingPathComponent("settings-v3.json")
    let store = SettingsStoreV2(fileURL: fileURL)

    var initial = AppSettingsV2.defaults
    initial.lastPermissionPromptAt = 111
    _ = try store.save(initial)

    let saved = try store.update { settings in
        settings.hotkey = "Control+Alt+K"
        settings.launchAtLogin = true
        settings.showConfirmation = false
    }

    #expect(saved.hotkey == "Control+Alt+K")
    #expect(saved.launchAtLogin)
    #expect(saved.showConfirmation == false)
    #expect(saved.lastPermissionPromptAt == 111)
    #expect(saved.schemaVersion == AppSettingsV2.schemaVersionValue)

    let reread = store.load()
    #expect(reread == saved)
}
