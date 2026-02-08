import Testing
@testable import TextShotSettings

@Test
func shortcutAvailabilityRejectsInvalidSyntax() {
    let checker = ShortcutAvailabilityChecker(
        symbolicHotkeysProvider: { nil },
        registrationProbe: { _, _ in true }
    )

    let result = checker.availability(for: "A")
    #expect(result == .unavailable("Shortcut must include at least one modifier, or use an F-key."))
}

@Test
func shortcutAvailabilityRejectsSystemConflict() {
    let components = ShortcutCodec.carbonHotkeyComponents(from: "CommandOrControl+Shift+2")
    #expect(components != nil)

    let checker = ShortcutAvailabilityChecker(
        symbolicHotkeysProvider: {
            guard let components else { return nil }
            return [
                "AppleSymbolicHotKeys": [
                    "60": [
                        "enabled": 1,
                        "value": [
                            "parameters": [components.keyCode, components.modifiers, 0],
                            "type": "standard"
                        ]
                    ]
                ]
            ]
        },
        registrationProbe: { _, _ in true }
    )

    let result = checker.availability(for: "CommandOrControl+Shift+2")
    #expect(result == .unavailable("Shortcut conflicts with a macOS system shortcut."))
}

@Test
func shortcutAvailabilityAcceptsFunctionKeyWithoutModifier() {
    let checker = ShortcutAvailabilityChecker(
        symbolicHotkeysProvider: { nil },
        registrationProbe: { _, _ in true }
    )

    let result = checker.availability(for: "F8")
    #expect(result == .available)
}
