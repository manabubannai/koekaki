import AppKit

/// 右⌥(option) キーの押下/解放を監視する。
/// 注意: CGEventTapコールバック内で同期的にキー送出するとmacOS 26でデッドロックするため、
/// コールバックからは必ず非同期でハンドラを呼ぶ(eikanaでの知見)。
final class HotKeyMonitor {
    private var tap: CFMachPort?
    var onDown: (() -> Void)?
    var onUp: (() -> Void)?
    private var pressed = false

    private static let rightOptionKeyCode: Int64 = 61

    func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .flagsChanged else { return }
        guard event.getIntegerValueField(.keyboardEventKeycode) == Self.rightOptionKeyCode else { return }
        let down = event.flags.contains(.maskAlternate)
        if down && !pressed {
            pressed = true
            DispatchQueue.main.async { self.onDown?() }
        } else if !down && pressed {
            pressed = false
            DispatchQueue.main.async { self.onUp?() }
        }
    }
}
