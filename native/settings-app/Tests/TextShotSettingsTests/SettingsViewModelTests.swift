import AppKit
import ShortcutRecorder
import Testing
@testable import TextShotSettings

private final class StubHotkeyController: HotkeyRecorderBindingProviding {
    let defaultsController: NSUserDefaultsController = .shared
    let defaultsKeyPath = HotkeyManager.defaultsKeyPath
    let bindingOptions: [NSBindingOption: Any] = [
        .valueTransformerName: NSValueTransformerName.keyedUnarchiveFromDataTransformerName
    ]

    var recorderAvailabilityIssue: String?
    var onShortcutChanged: ((Shortcut) -> Void)?
    var activeShortcut: Shortcut?

    func validateForRecorder(_ shortcut: Shortcut) throws {
        try HotkeyManager.validateNoModifierRule(shortcut)
    }
}

@MainActor
@Test
func launchToggleAppliesImmediatelyWhenSaveSucceeds() {
    let hotkeyController = StubHotkeyController()
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        onApplySettings: { editable in .success(editable) }
    )

    model.launchAtLoginBinding.wrappedValue = true

    #expect(model.settings.launchAtLogin)
    #expect(model.errorMessage.isEmpty)
}

@MainActor
@Test
func launchToggleRollsBackWhenSaveFails() {
    let hotkeyController = StubHotkeyController()
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        onApplySettings: { _ in .failure(.message("Failed to save settings")) }
    )

    model.launchAtLoginBinding.wrappedValue = true

    #expect(model.settings.launchAtLogin == AppSettingsV2.defaults.launchAtLogin)
    #expect(model.errorMessage == "Failed to save settings")
}

@MainActor
@Test
func syncHotkeyDisplayUpdatesHotkeyText() {
    let hotkeyController = StubHotkeyController()
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        onApplySettings: { editable in .success(editable) }
    )

    let shortcut = Shortcut(keyEquivalent: "⌃⌥K")!
    model.syncHotkeyDisplay(with: shortcut)

    #expect(model.settings.hotkey == HotkeyManager.displayString(for: shortcut))
}

@MainActor
@Test
func recorderAvailabilityIssuePassesThroughController() {
    let hotkeyController = StubHotkeyController()
    hotkeyController.recorderAvailabilityIssue = "Missing recorder assets"

    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        onApplySettings: { editable in .success(editable) }
    )

    #expect(model.recorderAvailabilityIssue == "Missing recorder assets")
}
