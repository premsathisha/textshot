import Carbon
import Foundation

protocol HotkeyManaging: AnyObject {
    var onHotkeyPressed: (() -> Void)? { get set }
    @discardableResult
    func apply(accelerator: String) throws -> String
}

enum HotkeyApplyError: LocalizedError {
    case invalidShortcut
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .invalidShortcut:
            return "Shortcut key is not supported."
        case .registrationFailed:
            return "Shortcut is already in use by another app."
        }
    }
}

extension HotkeyManager: HotkeyManaging {}

final class HotkeyManager {
    private let hotkeySignature = OSType(0x54534854)
    private var eventHandlerRef: EventHandlerRef?
    private var activeHotkeyRef: EventHotKeyRef?

    private(set) var activeAccelerator: String?
    var onHotkeyPressed: (() -> Void)?

    init() {
        installEventHandler()
    }

    deinit {
        if let activeHotkeyRef {
            UnregisterEventHotKey(activeHotkeyRef)
        }
    }

    @discardableResult
    func apply(accelerator: String) throws -> String {
        guard let components = ShortcutCodec.carbonHotkeyComponents(from: accelerator) else {
            throw HotkeyApplyError.invalidShortcut
        }

        let normalized = accelerator.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeAccelerator == normalized {
            return normalized
        }

        var nextRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: hotkeySignature, id: 1)
        let status = RegisterEventHotKey(
            components.keyCode,
            components.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &nextRef
        )

        guard status == noErr, let nextRef else {
            throw HotkeyApplyError.registrationFailed
        }

        if let activeHotkeyRef {
            UnregisterEventHotKey(activeHotkeyRef)
        }

        activeHotkeyRef = nextRef
        activeAccelerator = normalized
        return normalized
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let unmanagedSelf = Unmanaged.passUnretained(self)
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            if status == noErr, hotkeyID.signature == manager.hotkeySignature {
                manager.onHotkeyPressed?()
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            unmanagedSelf.toOpaque(),
            &eventHandlerRef
        )
    }
}
