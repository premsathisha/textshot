import Foundation
import KeyboardShortcuts

final class HotkeyBindingController: HotkeyManaging, HotkeyRecorderBindingProviding {
    var onHotkeyPressed: (() -> Void)?
    var onShortcutChanged: ((AppHotkeyShortcut?) -> Void)?

    let recorderName: KeyboardShortcuts.Name = .globalCaptureHotkey

    var recorderAvailabilityIssue: String? {
        nil
    }

    var activeShortcut: AppHotkeyShortcut? {
        KeyboardShortcuts.getShortcut(for: recorderName)
    }

    init() {
        if KeyboardShortcuts.getShortcut(for: recorderName) == nil {
            KeyboardShortcuts.setShortcut(HotkeyManager.defaultShortcut, for: recorderName)
        }

        KeyboardShortcuts.onKeyDown(for: recorderName) { [weak self] in
            self?.onHotkeyPressed?()
        }
    }

    @discardableResult
    func apply(shortcut: AppHotkeyShortcut?) throws -> AppHotkeyShortcut? {
        try validateForRecorder(shortcut)
        KeyboardShortcuts.setShortcut(shortcut, for: recorderName)
        onShortcutChanged?(shortcut)
        return shortcut
    }

    @discardableResult
    func resetToDefault() throws -> AppHotkeyShortcut {
        let shortcut = HotkeyManager.defaultShortcut
        KeyboardShortcuts.setShortcut(shortcut, for: recorderName)
        onShortcutChanged?(shortcut)
        return shortcut
    }

    func validateForRecorder(_ shortcut: AppHotkeyShortcut?) throws {
        try HotkeyManager.validateNoModifierRule(shortcut)
    }
}
