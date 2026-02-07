import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    let onShortcut: (String) -> Void
    let onInvalid: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onShortcut = onShortcut
        view.onInvalid = onInvalid
        view.requestFocus()
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.onShortcut = onShortcut
        nsView.onInvalid = onInvalid
        nsView.requestFocus()
    }
}

final class ShortcutCaptureView: NSView {
    var onShortcut: ((String) -> Void)?
    var onInvalid: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestFocus()
    }

    func requestFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let window = self.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if let accelerator = ShortcutCodec.accelerator(from: event) {
            onShortcut?(accelerator)
            return
        }

        onInvalid?()
    }
}
