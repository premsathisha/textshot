import Testing
@testable import TextShotSettings

@Test
func shortcutCodecUsesCommandOrControlWhenCommandPresent() {
    let accelerator = ShortcutCodec.accelerator(modifiers: [.command, .shift], key: "2")
    #expect(accelerator == "CommandOrControl+Shift+2")
}

@Test
func shortcutCodecUsesControlWhenNoCommandPresent() {
    let accelerator = ShortcutCodec.accelerator(modifiers: [.control, .alt], key: "k")
    #expect(accelerator == "Control+Alt+K")
}

@Test
func shortcutCodecAllowsFunctionKeyWithoutModifier() {
    let accelerator = ShortcutCodec.accelerator(modifiers: [], key: "F8")
    #expect(accelerator == "F8")
}

@Test
func shortcutCodecRejectsPrintableWithoutModifier() {
    let validation = ShortcutCodec.validateAccelerator("A")
    #expect(validation == "Shortcut must include at least one modifier, or use an F-key.")
}
