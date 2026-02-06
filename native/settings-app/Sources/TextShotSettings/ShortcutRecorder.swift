import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    let onShortcut: (String) -> Void
    let onInvalid: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onShortcut = onShortcut
        view.onInvalid = onInvalid
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.onShortcut = onShortcut
        nsView.onInvalid = onInvalid
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class ShortcutCaptureView: NSView {
    var onShortcut: ((String) -> Void)?
    var onInvalid: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if let accelerator = ShortcutCodec.accelerator(from: event) {
            onShortcut?(accelerator)
            return
        }

        onInvalid?()
    }
}
