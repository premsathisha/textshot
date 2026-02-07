import AppKit
import Carbon
import Foundation

enum ShortcutModifier: CaseIterable, Hashable {
    case command
    case control
    case alt
    case shift
}

enum ShortcutCodec {
    private static let allowedSpecialKeys: Set<String> = [
        "SPACE", "TAB", "ENTER", "ESCAPE", "BACKSPACE", "DELETE",
        "UP", "DOWN", "LEFT", "RIGHT", "HOME", "END", "PAGEUP", "PAGEDOWN"
    ]

    private static let keyCodeMap: [UInt16: String] = [
        36: "Enter",
        48: "Tab",
        49: "Space",
        51: "Backspace",
        53: "Escape",
        117: "Delete",
        123: "Left",
        124: "Right",
        125: "Down",
        126: "Up",
        115: "Home",
        119: "End",
        116: "PageUp",
        121: "PageDown",
        122: "F1",
        120: "F2",
        99: "F3",
        118: "F4",
        96: "F5",
        97: "F6",
        98: "F7",
        100: "F8",
        101: "F9",
        109: "F10",
        103: "F11",
        111: "F12"
    ]

    private static let tokenToKeyCodeMap: [String: UInt32] = [
        "A": UInt32(kVK_ANSI_A),
        "B": UInt32(kVK_ANSI_B),
        "C": UInt32(kVK_ANSI_C),
        "D": UInt32(kVK_ANSI_D),
        "E": UInt32(kVK_ANSI_E),
        "F": UInt32(kVK_ANSI_F),
        "G": UInt32(kVK_ANSI_G),
        "H": UInt32(kVK_ANSI_H),
        "I": UInt32(kVK_ANSI_I),
        "J": UInt32(kVK_ANSI_J),
        "K": UInt32(kVK_ANSI_K),
        "L": UInt32(kVK_ANSI_L),
        "M": UInt32(kVK_ANSI_M),
        "N": UInt32(kVK_ANSI_N),
        "O": UInt32(kVK_ANSI_O),
        "P": UInt32(kVK_ANSI_P),
        "Q": UInt32(kVK_ANSI_Q),
        "R": UInt32(kVK_ANSI_R),
        "S": UInt32(kVK_ANSI_S),
        "T": UInt32(kVK_ANSI_T),
        "U": UInt32(kVK_ANSI_U),
        "V": UInt32(kVK_ANSI_V),
        "W": UInt32(kVK_ANSI_W),
        "X": UInt32(kVK_ANSI_X),
        "Y": UInt32(kVK_ANSI_Y),
        "Z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0),
        "1": UInt32(kVK_ANSI_1),
        "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4),
        "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6),
        "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9),
        "SPACE": UInt32(kVK_Space),
        "TAB": UInt32(kVK_Tab),
        "ENTER": UInt32(kVK_Return),
        "ESCAPE": UInt32(kVK_Escape),
        "BACKSPACE": UInt32(kVK_Delete),
        "DELETE": UInt32(kVK_ForwardDelete),
        "UP": UInt32(kVK_UpArrow),
        "DOWN": UInt32(kVK_DownArrow),
        "LEFT": UInt32(kVK_LeftArrow),
        "RIGHT": UInt32(kVK_RightArrow),
        "HOME": UInt32(kVK_Home),
        "END": UInt32(kVK_End),
        "PAGEUP": UInt32(kVK_PageUp),
        "PAGEDOWN": UInt32(kVK_PageDown),
        "F1": UInt32(kVK_F1),
        "F2": UInt32(kVK_F2),
        "F3": UInt32(kVK_F3),
        "F4": UInt32(kVK_F4),
        "F5": UInt32(kVK_F5),
        "F6": UInt32(kVK_F6),
        "F7": UInt32(kVK_F7),
        "F8": UInt32(kVK_F8),
        "F9": UInt32(kVK_F9),
        "F10": UInt32(kVK_F10),
        "F11": UInt32(kVK_F11),
        "F12": UInt32(kVK_F12),
        "F13": UInt32(kVK_F13),
        "F14": UInt32(kVK_F14),
        "F15": UInt32(kVK_F15),
        "F16": UInt32(kVK_F16),
        "F17": UInt32(kVK_F17),
        "F18": UInt32(kVK_F18),
        "F19": UInt32(kVK_F19),
        "F20": UInt32(kVK_F20)
    ]

    static func accelerator(from event: NSEvent) -> String? {
        var modifiers = Set<ShortcutModifier>()
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.alt) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }

        let key = keyToken(from: event)
        return accelerator(modifiers: modifiers, key: key)
    }

    static func accelerator(modifiers: Set<ShortcutModifier>, key: String?) -> String? {
        guard !modifiers.isEmpty else { return nil }
        guard let rawKey = key?.trimmingCharacters(in: .whitespacesAndNewlines), !rawKey.isEmpty else { return nil }

        let normalizedKey = normalizeKey(rawKey)
        guard isAllowedKeyToken(normalizedKey) else { return nil }

        var parts: [String] = []

        if modifiers.contains(.command) {
            parts.append("CommandOrControl")
        } else if modifiers.contains(.control) {
            parts.append("Control")
        }

        if modifiers.contains(.alt) {
            parts.append("Alt")
        }

        if modifiers.contains(.shift) {
            parts.append("Shift")
        }

        if parts.isEmpty {
            return nil
        }

        parts.append(normalizedKey)
        return parts.joined(separator: "+")
    }

    static func validateAccelerator(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return "Shortcut is required."
        }

        let parts = value.split(separator: "+").map { String($0) }
        if parts.count < 2 {
            return "Shortcut must include at least one modifier and one key."
        }

        let key = normalizeKey(parts[parts.count - 1])
        if !isAllowedKeyToken(key) {
            return "Shortcut key is not supported."
        }

        let modifiers = Set(parts.dropLast().map { normalizeModifier($0) })
        let allowedModifiers: Set<String> = ["COMMAND", "COMMANDORCONTROL", "CONTROL", "CTRL", "ALT", "OPTION", "SHIFT"]
        if modifiers.isEmpty || !modifiers.isSubset(of: allowedModifiers) {
            return "Shortcut modifiers are invalid."
        }

        return nil
    }

    static func parseAccelerator(_ rawValue: String) -> (modifiers: Set<ShortcutModifier>, key: String)? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "+").map { String($0) }
        guard parts.count >= 2 else { return nil }

        let normalizedKey = normalizeKey(parts[parts.count - 1])
        guard isAllowedKeyToken(normalizedKey) else { return nil }

        var modifiers = Set<ShortcutModifier>()
        for rawModifier in parts.dropLast() {
            let modifier = normalizeModifier(rawModifier)
            switch modifier {
            case "COMMAND", "COMMANDORCONTROL":
                modifiers.insert(.command)
            case "CONTROL", "CTRL":
                modifiers.insert(.control)
            case "ALT", "OPTION":
                modifiers.insert(.alt)
            case "SHIFT":
                modifiers.insert(.shift)
            default:
                return nil
            }
        }

        guard !modifiers.isEmpty else { return nil }
        return (modifiers: modifiers, key: normalizedKey)
    }

    static func carbonHotkeyComponents(from accelerator: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        guard let parsed = parseAccelerator(accelerator) else { return nil }
        guard let keyCode = tokenToKeyCodeMap[parsed.key] else { return nil }
        return (keyCode: keyCode, modifiers: carbonModifiers(from: parsed.modifiers))
    }

    private static func normalizeModifier(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func normalizeKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func carbonModifiers(from modifiers: Set<ShortcutModifier>) -> UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) {
            value |= UInt32(cmdKey)
        }
        if modifiers.contains(.control) {
            value |= UInt32(controlKey)
        }
        if modifiers.contains(.alt) {
            value |= UInt32(optionKey)
        }
        if modifiers.contains(.shift) {
            value |= UInt32(shiftKey)
        }
        return value
    }

    private static func keyToken(from event: NSEvent) -> String? {
        if let mapped = keyCodeMap[event.keyCode] {
            return mapped
        }

        guard let chars = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines), chars.count == 1 else {
            return nil
        }

        return normalizeKey(chars)
    }

    private static func isAllowedKeyToken(_ key: String) -> Bool {
        if key.range(of: "^[A-Z0-9]$", options: .regularExpression) != nil {
            return true
        }

        if key.range(of: "^F([1-9]|1[0-9]|2[0-4])$", options: .regularExpression) != nil {
            return true
        }

        return allowedSpecialKeys.contains(key)
    }
}
