import KeyboardShortcuts
import Testing
@testable import TextShotSettings

private final class StubHotkeyController: HotkeyManaging, HotkeyRecorderBindingProviding {
    var onHotkeyPressed: (() -> Void)?
    var onShortcutChanged: ((AppHotkeyShortcut?) -> Void)?
    var activeShortcut: AppHotkeyShortcut?
    let recorderName: KeyboardShortcuts.Name = .globalCaptureHotkey
    var recorderAvailabilityIssue: String?

    @discardableResult
    func apply(shortcut: AppHotkeyShortcut?) throws -> AppHotkeyShortcut? {
        try validateForRecorder(shortcut)
        activeShortcut = shortcut
        onShortcutChanged?(shortcut)
        return shortcut
    }

    @discardableResult
    func resetToDefault() throws -> AppHotkeyShortcut {
        activeShortcut = HotkeyManager.defaultShortcut
        onShortcutChanged?(activeShortcut)
        return HotkeyManager.defaultShortcut
    }

    func validateForRecorder(_ shortcut: AppHotkeyShortcut?) throws {
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

    let shortcut = AppHotkeyShortcut(.k, modifiers: [.control, .option])
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
