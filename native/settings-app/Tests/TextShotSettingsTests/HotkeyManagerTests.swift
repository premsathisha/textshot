import KeyboardShortcuts
import Testing
@testable import TextShotSettings

@Test
func hotkeyManagerAllowsFunctionKeyWithoutModifiers() throws {
    let shortcut = AppHotkeyShortcut(.f8, modifiers: [])
    try HotkeyManager.validateNoModifierRule(shortcut)
}

@Test
func hotkeyManagerRejectsPrintableWithoutModifiers() {
    let shortcut = AppHotkeyShortcut(.a, modifiers: [])

    #expect(throws: HotkeyApplyError.invalidShortcut) {
        try HotkeyManager.validateNoModifierRule(shortcut)
    }
}

@Test
func hotkeyBindingControllerApplyAndResetFlow() throws {
    KeyboardShortcuts.setShortcut(nil, for: .globalCaptureHotkey)
    defer {
        KeyboardShortcuts.setShortcut(nil, for: .globalCaptureHotkey)
    }

    let controller = HotkeyBindingController()
    let applied = AppHotkeyShortcut(.k, modifiers: [.control, .option])
    let active = try controller.apply(shortcut: applied)

    #expect(active == applied)
    #expect(controller.activeShortcut == applied)

    let reset = try controller.resetToDefault()
    #expect(reset == HotkeyManager.defaultShortcut)
    #expect(controller.activeShortcut == HotkeyManager.defaultShortcut)
}

@Test
func optionGuardrailMessageRequiresCommandOrControl() {
    let optionOnly = AppHotkeyShortcut(.k, modifiers: [.option])
    #expect(HotkeyManager.macOS15OptionGuardrailMessage(for: optionOnly) != nil)

    let optionWithCommand = AppHotkeyShortcut(.k, modifiers: [.option, .command])
    #expect(HotkeyManager.macOS15OptionGuardrailMessage(for: optionWithCommand) == nil)
}
