import AppKit
import Foundation

protocol ClipboardWriting {
    func write(_ text: String)
}

final class ClipboardService {
    func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

extension ClipboardService: ClipboardWriting {}
