import AppKit
import ApplicationServices

/// 書き起こし結果をクリップボードへ入れ、可能なら前面アプリに⌘Vを送って自動で貼り付ける。
enum Paster {
    static let autoPasteKey = "autoPaste"

    static var autoPasteEnabled: Bool {
        UserDefaults.standard.object(forKey: autoPasteKey) as? Bool ?? true
    }

    /// 貼り付けまでできたら true、クリップボードコピー止まりなら false を返す。
    @discardableResult
    static func deliver(_ text: String) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        guard autoPasteEnabled, frontAppIsOtherApp, ensureAccessibility(prompt: true) else {
            return false
        }
        // ペーストボード反映を待ってから送る。イベント送出は必ず非同期で(eikanaの知見)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { sendCmdV() }
        return true
    }

    /// 自分が最前面だと⌘Vが自分に届くだけなので、その場合は貼り付けない。
    private static var frontAppIsOtherApp: Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
            != ProcessInfo.processInfo.processIdentifier
    }

    /// アクセシビリティ許可の確認。未許可なら(prompt時)システムの許可ダイアログを出す。
    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        if AXIsProcessTrusted() { return true }
        if prompt {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
        return false
    }

    private static func sendCmdV() {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
