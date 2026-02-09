import AppKit
import Carbon.HIToolbox
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let globalCaptureHotkey = Self("globalCaptureHotkey")
}

typealias AppHotkeyShortcut = KeyboardShortcuts.Shortcut

protocol HotkeyManaging: AnyObject {
    var onHotkeyPressed: (() -> Void)? { get set }
    var activeShortcut: AppHotkeyShortcut? { get }

    @discardableResult
    func apply(shortcut: AppHotkeyShortcut?) throws -> AppHotkeyShortcut?

    @discardableResult
    func resetToDefault() throws -> AppHotkeyShortcut
}

protocol HotkeyRecorderBindingProviding: AnyObject {
    var recorderName: KeyboardShortcuts.Name { get }
    var recorderAvailabilityIssue: String? { get }
    var onShortcutChanged: ((AppHotkeyShortcut?) -> Void)? { get set }

    func validateForRecorder(_ shortcut: AppHotkeyShortcut?) throws
}

enum HotkeyApplyError: LocalizedError, Equatable {
    case invalidShortcut

    var errorDescription: String? {
        switch self {
        case .invalidShortcut:
            return "Unsupported shortcut. Use one or more modifiers, or an F-key."
        }
    }
}

enum HotkeyManager {
    static let defaultShortcut = AppHotkeyShortcut(.two, modifiers: [.shift, .command])

    @MainActor
    static func displayString(for shortcut: AppHotkeyShortcut?) -> String {
        shortcut?.description ?? "Not set"
    }

    static func validateNoModifierRule(_ shortcut: AppHotkeyShortcut?) throws {
        guard let shortcut else {
            return
        }

        guard isAllowedNoModifierShortcut(shortcut) || hasAnyModifier(shortcut) else {
            throw HotkeyApplyError.invalidShortcut
        }
    }

    static func macOS15OptionGuardrailMessage(for shortcut: AppHotkeyShortcut?) -> String? {
        guard let shortcut else {
            return nil
        }

        let modifiers = shortcut.modifiers.intersection([.command, .option, .control, .shift])
        guard modifiers.contains(.option) else {
            return nil
        }

        let hasCommandOrControl = modifiers.contains(.command) || modifiers.contains(.control)
        guard !hasCommandOrControl else {
            return nil
        }

        return "Option-only shortcuts may not fire reliably on macOS 15. Prefer adding Command or Control."
    }

    private static func hasAnyModifier(_ shortcut: AppHotkeyShortcut) -> Bool {
        let modifiers = shortcut.modifiers.intersection([.command, .option, .control, .shift])
        return !modifiers.isEmpty
    }

    private static func isAllowedNoModifierShortcut(_ shortcut: AppHotkeyShortcut) -> Bool {
        let modifiers = shortcut.modifiers.intersection([.command, .option, .control, .shift])
        guard modifiers.isEmpty else {
            return false
        }

        return isFunctionKey(shortcut)
    }

    static func isFunctionKey(_ shortcut: AppHotkeyShortcut) -> Bool {
        let fKeyRawValues: Set<Int> = [
            Int(kVK_F1), Int(kVK_F2), Int(kVK_F3), Int(kVK_F4), Int(kVK_F5),
            Int(kVK_F6), Int(kVK_F7), Int(kVK_F8), Int(kVK_F9), Int(kVK_F10),
            Int(kVK_F11), Int(kVK_F12), Int(kVK_F13), Int(kVK_F14), Int(kVK_F15),
            Int(kVK_F16), Int(kVK_F17), Int(kVK_F18), Int(kVK_F19), Int(kVK_F20)
        ]

        return fKeyRawValues.contains(shortcut.carbonKeyCode)
    }
}
