import KeyboardShortcuts
import SwiftUI

struct KeyboardShortcutField: View {
    let hotkeyController: any HotkeyManaging & HotkeyRecorderBindingProviding
    @Binding var shortcut: AppHotkeyShortcut?
    let onError: (String) -> Void
    let onWarning: (String?) -> Void

    var body: some View {
        KeyboardShortcuts.Recorder(
            shortcut: $shortcut,
            onChange: { newValue in
                do {
                    let applied = try hotkeyController.apply(shortcut: newValue)
                    onError("")
                    onWarning(HotkeyManager.macOS15OptionGuardrailMessage(for: applied))
                } catch {
                    shortcut = hotkeyController.activeShortcut
                    onWarning(nil)
                    onError(error.localizedDescription)
                }
            }
        )
    }
}
