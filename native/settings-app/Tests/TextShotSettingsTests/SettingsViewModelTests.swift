import Testing
@testable import TextShotSettings

@MainActor
@Test
func recordingShortcutUpdatesStateWhenApplySucceeds() {
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        onSave: { .success($0) },
        onApplyHotkey: { _ in .success("Control+Alt+K") },
        onResetHotkey: { .success(AppSettingsV2.defaults.hotkey) }
    )

    model.beginShortcutRecording()
    model.onCapturedShortcut("Control+Alt+K")

    #expect(model.isRecording == false)
    #expect(model.settings.hotkey == "Control+Alt+K")
    #expect(model.statusMessage == "Shortcut updated")
    #expect(model.errorMessage.isEmpty)
}

@MainActor
@Test
func recordingShortcutKeepsPreviousOnFailure() {
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        onSave: { .success($0) },
        onApplyHotkey: { _ in .failure(.message("Shortcut is already in use by another app.")) },
        onResetHotkey: { .success(AppSettingsV2.defaults.hotkey) }
    )

    model.beginShortcutRecording()
    model.onCapturedShortcut("Control+Alt+K")

    #expect(model.isRecording == false)
    #expect(model.settings.hotkey == AppSettingsV2.defaults.hotkey)
    #expect(model.statusMessage.isEmpty)
    #expect(model.errorMessage == "Shortcut is already in use by another app.")
}
