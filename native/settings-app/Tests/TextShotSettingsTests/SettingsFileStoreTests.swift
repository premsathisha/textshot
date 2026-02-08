import Foundation
import Testing
@testable import TextShotSettings

@Test
func settingsStoreRoundTripPreservesPromptMetadata() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let fileURL = tempDir.appendingPathComponent("settings-v2.json")
    let store = SettingsStoreV2(fileURL: fileURL)

    var initial = AppSettingsV2.defaults
    initial.lastPermissionPromptAt = 111
    initial.lastAccessibilityPromptAt = 222
    _ = try store.save(initial)

    let saved = try store.update { settings in
        settings.hotkey = "Control+Alt+K"
        settings.launchAtLogin = true
        settings.showConfirmation = false
        settings.autoPaste = true
    }

    #expect(saved.hotkey == "Control+Alt+K")
    #expect(saved.launchAtLogin)
    #expect(saved.showConfirmation == false)
    #expect(saved.autoPaste)
    #expect(saved.lastPermissionPromptAt == 111)
    #expect(saved.lastAccessibilityPromptAt == 222)

    let reread = store.load()
    #expect(reread == saved)
}
