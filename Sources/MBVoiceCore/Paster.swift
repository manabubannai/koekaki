import AppKit

/// クリップボード経由でカーソル位置に貼り付ける。
/// 貼り付け後もテキストはクリップボードに残す(貼り付け失敗時の保険)。
final class Paster {
    func paste(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKey: CGKeyCode = 9  // V
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
}
