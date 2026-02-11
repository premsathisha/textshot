import AppKit
import Foundation
import QuartzCore

@MainActor
protocol ToastPresenting {
    func show(_ message: String)
}

private final class RoundedToastContainerView: NSView {
    private let cornerRadius: CGFloat

    init(frame frameRect: NSRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 16
        layer?.shadowOffset = CGSize(width: 0, height: -2)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        layer?.shadowPath = shadowPath
    }
}

private final class RoundedVisualEffectView: NSVisualEffectView {
    private let cornerRadius: CGFloat

    init(frame frameRect: NSRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: frameRect)

        material = .hudWindow
        state = .active
        blendingMode = .withinWindow
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = cornerRadius
        updateMaskImage()
    }

    private func updateMaskImage() {
        guard bounds.width > 0, bounds.height > 0 else {
            maskImage = nil
            return
        }

        let size = bounds.size
        maskImage = NSImage(size: size, flipped: false) { _ in
            NSColor.clear.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
            NSColor.white.setFill()
            NSBezierPath(
                roundedRect: NSRect(origin: .zero, size: size),
                xRadius: self.cornerRadius,
                yRadius: self.cornerRadius
            ).fill()
            return true
        }
    }
}

@MainActor
final class ToastPresenter {
    private let panel: NSPanel
    private let messageLabel = NSTextField(labelWithString: "")

    private var hideWorkItem: DispatchWorkItem?
    private var isVisible = false

    private let width: CGFloat = 250
    private let height: CGFloat = 92
    private let holdDuration: TimeInterval = 2.0
    private let enterDuration: TimeInterval = 0.14
    private let exitDuration: TimeInterval = 0.22
    private let cornerRadius: CGFloat = 14

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        let container = RoundedToastContainerView(
            frame: panel.contentView?.bounds ?? .zero,
            cornerRadius: cornerRadius
        )
        container.autoresizingMask = [.width, .height]

        let root = RoundedVisualEffectView(frame: container.bounds, cornerRadius: cornerRadius)
        root.autoresizingMask = [.width, .height]

        messageLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        messageLabel.alignment = .center
        messageLabel.textColor = .labelColor
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            messageLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor)
        ])

        container.addSubview(root)
        panel.contentView = container
        panel.alphaValue = 0
    }

    func show(_ message: String) {
        hideWorkItem?.cancel()

        messageLabel.stringValue = message
        positionPanel()

        // Instant text at t=0, then animate container in.
        panel.orderFrontRegardless()

        let targetFrame = panel.frame
        let startFrame = targetFrame.offsetBy(dx: 0, dy: -10)
        panel.setFrame(startFrame, display: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = enterDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }

        isVisible = true
        let hideItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = hideItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: hideItem)
    }

    private func hide() {
        guard isVisible else { return }
        let targetFrame = panel.frame.offsetBy(dx: 0, dy: 8)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = exitDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.panel.orderOut(nil)
                self.isVisible = false
            }
        }
    }

    private func positionPanel() {
        let display = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let frame = display?.visibleFrame else { return }

        let origin = NSPoint(
            x: frame.midX - (width / 2),
            y: frame.midY - (height / 2)
        )

        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }
}

extension ToastPresenter: ToastPresenting {}
