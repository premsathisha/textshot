import XCTest
@testable import TextShotSettings

final class ShortcutCodecTests: XCTestCase {
    func testAcceleratorPrefersCommandOrControlWhenCommandPresent() {
        let accelerator = ShortcutCodec.accelerator(modifiers: [.command, .shift], key: "2")
        XCTAssertEqual(accelerator, "CommandOrControl+Shift+2")
    }

    func testAcceleratorUsesControlWhenNoCommandPresent() {
        let accelerator = ShortcutCodec.accelerator(modifiers: [.control, .alt], key: "k")
        XCTAssertEqual(accelerator, "Control+Alt+K")
    }

    func testAcceleratorRequiresModifier() {
        XCTAssertNil(ShortcutCodec.accelerator(modifiers: [], key: "A"))
    }

    func testValidateRejectsMissingModifier() {
        XCTAssertNotNil(ShortcutCodec.validateAccelerator("A"))
    }

    func testValidateRejectsUnknownKeyToken() {
        XCTAssertNotNil(ShortcutCodec.validateAccelerator("CommandOrControl+VolumeUp"))
    }

    func testValidateAcceptsFunctionKey() {
        XCTAssertNil(ShortcutCodec.validateAccelerator("CommandOrControl+F12"))
    }
}
