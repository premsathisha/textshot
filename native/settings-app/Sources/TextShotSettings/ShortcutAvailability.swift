import Carbon
import Foundation

enum ShortcutAvailabilityResult: Equatable {
    case available
    case unavailable(String)
}

protocol ShortcutAvailabilityChecking {
    func availability(for accelerator: String) -> ShortcutAvailabilityResult
}

struct ShortcutAvailabilityChecker: ShortcutAvailabilityChecking {
    private static let symbolicHotkeyDomainName = "com.apple.symbolichotkeys"
    private static let relevantModifierMask: UInt32 = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    private let symbolicHotkeysProvider: () -> [String: Any]?
    private let registrationProbe: (UInt32, UInt32) -> Bool

    init(
        symbolicHotkeysProvider: @escaping () -> [String: Any]? = {
            UserDefaults.standard.persistentDomain(forName: ShortcutAvailabilityChecker.symbolicHotkeyDomainName)
        },
        registrationProbe: @escaping (UInt32, UInt32) -> Bool = ShortcutAvailabilityChecker.probeRegistration
    ) {
        self.symbolicHotkeysProvider = symbolicHotkeysProvider
        self.registrationProbe = registrationProbe
    }

    func availability(for accelerator: String) -> ShortcutAvailabilityResult {
        if let validation = ShortcutCodec.validateAccelerator(accelerator) {
            return .unavailable(validation)
        }

        guard let hotkey = ShortcutCodec.carbonHotkeyComponents(from: accelerator) else {
            return .unavailable("Shortcut key is not supported on this keyboard.")
        }

        if conflictsWithSystemShortcut(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers) {
            return .unavailable("Shortcut conflicts with a macOS system shortcut.")
        }

        if !registrationProbe(hotkey.keyCode, hotkey.modifiers) {
            return .unavailable("Shortcut is already in use by another app.")
        }

        return .available
    }

    private func conflictsWithSystemShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
        guard
            let domain = symbolicHotkeysProvider(),
            let entries = domain["AppleSymbolicHotKeys"] as? [String: Any]
        else {
            return false
        }

        let normalizedModifiers = modifiers & Self.relevantModifierMask
        for value in entries.values {
            guard
                let entry = value as? [String: Any],
                let enabled = Self.toUInt32(entry["enabled"]),
                enabled != 0,
                let entryValue = entry["value"] as? [String: Any],
                let parameters = entryValue["parameters"] as? [Any],
                parameters.count >= 2,
                let systemKeyCode = Self.toUInt32(parameters[0]),
                let systemModifiersRaw = Self.toUInt32(parameters[1])
            else {
                continue
            }

            let systemModifiers = systemModifiersRaw & Self.relevantModifierMask
            if systemKeyCode == keyCode && systemModifiers == normalizedModifiers {
                return true
            }
        }

        return false
    }

    private static func toUInt32(_ value: Any?) -> UInt32? {
        switch value {
        case let number as NSNumber:
            return number.uint32Value
        case let intValue as Int where intValue >= 0:
            return UInt32(intValue)
        case let int32Value as Int32 where int32Value >= 0:
            return UInt32(int32Value)
        case let uint32Value as UInt32:
            return uint32Value
        default:
            return nil
        }
    }

    private static func probeRegistration(keyCode: UInt32, modifiers: UInt32) -> Bool {
        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: OSType(0x54534854), id: UInt32(1))
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotkeyRef
        )
        if status == noErr {
            if let hotkeyRef {
                UnregisterEventHotKey(hotkeyRef)
            }
            return true
        }

        return false
    }
}
