import XCTest
@testable import TextShotSettings

final class ShortcutAvailabilityTests: XCTestCase {
    func testRejectsInvalidShortcutSyntax() {
        let checker = ShortcutAvailabilityChecker(
            symbolicHotkeysProvider: { nil },
            registrationProbe: { _, _ in true }
        )

        let result = checker.availability(for: "A")
        XCTAssertEqual(result, .unavailable("Shortcut must include at least one modifier and one key."))
    }

    func testRejectsSystemShortcutConflict() {
        let components = ShortcutCodec.carbonHotkeyComponents(from: "CommandOrControl+Shift+2")
        XCTAssertNotNil(components)

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
        XCTAssertEqual(result, .unavailable("Shortcut conflicts with a macOS system shortcut."))
    }

    func testRejectsHotkeyAlreadyInUse() {
        let checker = ShortcutAvailabilityChecker(
            symbolicHotkeysProvider: { nil },
            registrationProbe: { _, _ in false }
        )

        let result = checker.availability(for: "Control+Alt+K")
        XCTAssertEqual(result, .unavailable("Shortcut is already in use by another app."))
    }

    func testAcceptsShortcutWhenNoConflictsAreFound() {
        let checker = ShortcutAvailabilityChecker(
            symbolicHotkeysProvider: { nil },
            registrationProbe: { _, _ in true }
        )

        let result = checker.availability(for: "Control+Alt+K")
        XCTAssertEqual(result, .available)
    }
}
