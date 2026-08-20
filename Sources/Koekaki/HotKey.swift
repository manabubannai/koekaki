import AppKit
import Carbon.HIToolbox

/// ユーザーが設定するグローバルショートカット1つ分。UserDefaultsに保存する。
struct HotKeySetting: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var label: String

    static let `default` = HotKeySetting(keyCode: 49, modifiers: .option, label: "Space")
    static let fnOnly = HotKeySetting(keyCode: 63, modifiers: [], label: "Fn")

    /// Fn(🌐)単独。CarbonのRegisterEventHotKeyでは扱えないためNSEvent監視で拾う。
    var isFnOnly: Bool { keyCode == 63 && modifiers.isEmpty }

    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + label
    }

    /// CarbonのRegisterEventHotKeyが受け取る修飾キー形式へ変換する。
    var carbonModifiers: UInt32 {
        var c: UInt32 = 0
        if modifiers.contains(.command) { c |= UInt32(cmdKey) }
        if modifiers.contains(.option) { c |= UInt32(optionKey) }
        if modifiers.contains(.control) { c |= UInt32(controlKey) }
        if modifiers.contains(.shift) { c |= UInt32(shiftKey) }
        return c
    }

    static func load() -> HotKeySetting {
        let d = UserDefaults.standard
        guard d.object(forKey: "hotkeyKeyCode") != nil else { return .default }
        return HotKeySetting(
            keyCode: UInt16(d.integer(forKey: "hotkeyKeyCode")),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(d.integer(forKey: "hotkeyModifiers"))),
            label: d.string(forKey: "hotkeyLabel") ?? "Space"
        )
    }

    func save() {
        let d = UserDefaults.standard
        d.set(Int(keyCode), forKey: "hotkeyKeyCode")
        d.set(Int(modifiers.rawValue), forKey: "hotkeyModifiers")
        d.set(label, forKey: "hotkeyLabel")
    }

    /// keyCodeから表示用のキー名を作る。文字キーはイベントの文字をそのまま使う。
    static func keyLabel(for event: NSEvent) -> String {
        let special: [UInt16: String] = [
            49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        if let name = special[event.keyCode] { return name }
        return event.charactersIgnoringModifiers?.uppercased() ?? "?"
    }
}

/// グローバルショートカットの登録(Carbon RegisterEventHotKey)。
/// アクセシビリティ権限なしで、他アプリにフォーカスがあっても発火する。
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var fnMonitors: [Any] = []

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { center.onPress?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    func apply(_ setting: HotKeySetting) {
        if let r = hotKeyRef {
            UnregisterEventHotKey(r)
            hotKeyRef = nil
        }
        fnMonitors.forEach { NSEvent.removeMonitor($0) }
        fnMonitors.removeAll()

        if setting.isFnOnly {
            // Fn単独はCarbonで登録できないため、flagsChangedをNSEventで監視する。
            // 他アプリ使用中の検知(グローバル監視)にはアクセシビリティ許可が必要。
            let fire: (NSEvent) -> Void = { [weak self] event in
                guard event.keyCode == 63,
                      event.modifierFlags.contains(.function) else { return } // 押した瞬間のみ(離しは無視)
                DispatchQueue.main.async { self?.onPress?() }
            }
            if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: fire) {
                fnMonitors.append(global)
            }
            if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
                fire(event)
                return event
            }) {
                fnMonitors.append(local)
            }
            return
        }

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4B4F_454B), id: 1) // "KOEK"
        RegisterEventHotKey(UInt32(setting.keyCode), setting.carbonModifiers, id,
                            GetApplicationEventTarget(), 0, &ref)
        hotKeyRef = ref
    }
}
