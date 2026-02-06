import AppKit
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

    private static func normalizeModifier(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func normalizeKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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
