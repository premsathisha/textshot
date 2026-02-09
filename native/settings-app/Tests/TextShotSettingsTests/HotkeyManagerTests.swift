import AppKit
import Foundation
import ShortcutRecorder
import Testing
@testable import TextShotSettings

private final class StubGlobalShortcutMonitor: GlobalShortcutMonitoring {
    var actions: [ShortcutAction] = []

    func addAction(_ action: ShortcutAction, forKeyEvent keyEvent: KeyEventType) {
        actions.append(action)
    }

    func removeAction(_ action: ShortcutAction) {
        actions.removeAll { $0 === action }
    }
}

private final class StubValidator: ShortcutValidator {
    var errorToThrow: Error?

    override func validate(shortcut aShortcut: Shortcut) throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}

private func makeDefaultsController() -> NSUserDefaultsController {
    let suiteName = "HotkeyManagerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return NSUserDefaultsController(defaults: defaults, initialValues: nil)
}

private func decodeShortcut(from data: Data) throws -> Shortcut {
    guard let shortcut = try NSKeyedUnarchiver.unarchivedObject(ofClass: Shortcut.self, from: data) else {
        throw NSError(domain: "HotkeyManagerTests", code: 99)
    }
    return shortcut
}

@Test
func hotkeyManagerAllowsFunctionKeyWithoutModifiers() throws {
    let shortcut = Shortcut(keyEquivalent: "F8")!
    try HotkeyManager.validateNoModifierRule(shortcut)
}

@Test
func hotkeyManagerRejectsPrintableWithoutModifiers() {
    let shortcut = Shortcut(keyEquivalent: "A")!

    #expect(throws: HotkeyApplyError.invalidShortcut) {
        try HotkeyManager.validateNoModifierRule(shortcut)
    }
}

@Test
func hotkeyBindingControllerPersistsValidShortcut() throws {
    let defaultsController = makeDefaultsController()
    let monitor = StubGlobalShortcutMonitor()
    let validator = StubValidator()

    let controller = HotkeyBindingController(
        defaultsController: defaultsController,
        validator: validator,
        monitor: monitor
    )

    let shortcut = Shortcut(keyEquivalent: "⌃⌥K")!
    let active = try controller.apply(shortcut: shortcut)

    #expect(active.isEqual(shortcut))
    #expect(controller.activeShortcut?.isEqual(shortcut) == true)
    #expect(monitor.actions.count == 1)

    let persisted = defaultsController.defaults.data(forKey: HotkeyManager.defaultsDataKey)
    #expect(persisted != nil)

    if let persisted {
        let decoded = try decodeShortcut(from: persisted)
        #expect(decoded.isEqual(shortcut))
    }
}

@Test
func hotkeyBindingControllerWrapsValidatorConflictError() {
    let defaultsController = makeDefaultsController()
    let monitor = StubGlobalShortcutMonitor()
    let validator = StubValidator()
    validator.errorToThrow = NSError(domain: "Hotkey", code: 1, userInfo: [NSLocalizedDescriptionKey: "Shortcut already in use."])

    let controller = HotkeyBindingController(
        defaultsController: defaultsController,
        validator: validator,
        monitor: monitor
    )

    #expect(throws: HotkeyApplyError.conflict(message: "Shortcut already in use.")) {
        try controller.validateForRecorder(Shortcut(keyEquivalent: "⌃⌥K")!)
    }
}
