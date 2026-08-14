import AppKit

public struct AppConfig {
    public let appName: String
    public let aiModes: Bool
    public init(appName: String, aiModes: Bool) {
        self.appName = appName
        self.aiModes = aiModes
    }
}

public func runApp(config: AppConfig) {
    let app = NSApplication.shared
    let delegate = AppDelegate(config: config)
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

enum AppState {
    case idle
    case recording
    case processing
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let config: AppConfig
    var statusItem: NSStatusItem!
    let recorder = Recorder()
    let transcriber = Transcriber()
    let paster = Paster()
    let refiner = Refiner()
    let hotKey = HotKeyMonitor()
    var state: AppState = .idle
    var lastText: String = ""
    var refineMode: RefineMode {
        get { RefineMode(rawValue: UserDefaults.standard.string(forKey: "refineMode") ?? "") ?? .raw }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "refineMode") }
    }

    init(config: AppConfig) {
        self.config = config
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        rebuildMenu()

        Recorder.requestPermission()

        hotKey.onDown = { [weak self] in self?.beginRecording() }
        hotKey.onUp = { [weak self] in self?.endRecordingAndTranscribe() }
        if !hotKey.start() {
            // アクセシビリティ未許可。許可を促してメニュー操作のみで動かす
            let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }

    // MARK: - 録音フロー

    func beginRecording() {
        guard state == .idle else { return }
        do {
            try recorder.start()
            state = .recording
            updateIcon()
            NSSound(named: "Pop")?.play()
        } catch {
            showError("録音を開始できませんでした: \(error.localizedDescription)")
        }
    }

    func endRecordingAndTranscribe() {
        guard state == .recording, let url = recorder.stop() else { return }
        state = .processing
        updateIcon()
        NSSound(named: "Blow")?.play()

        let mode = config.aiModes ? refineMode : .raw
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                var text = try self.transcriber.transcribe(url)
                if mode != .raw, !text.isEmpty {
                    text = self.refiner.refine(text, mode: mode)
                }
                DispatchQueue.main.async {
                    self.state = .idle
                    self.updateIcon()
                    guard !text.isEmpty else { return }
                    self.lastText = text
                    self.rebuildMenu()
                    self.paster.paste(text)
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .idle
                    self.updateIcon()
                    self.showError("文字起こしに失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - UI

    func updateIcon() {
        let name: String
        let desc: String
        switch state {
        case .idle: name = "mic"; desc = "待機中"
        case .recording: name = "record.circle.fill"; desc = "録音中"
        case .processing: name = "ellipsis.circle"; desc = "文字起こし中"
        }
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: name, accessibilityDescription: desc)
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let hint = NSMenuItem(title: "右⌥(option)を押している間だけ録音", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: state == .recording ? "録音を停止して書き起こす" : "録音を開始",
                                action: #selector(toggleRecording), keyEquivalent: "r")
        toggle.target = self
        menu.addItem(toggle)

        if config.aiModes {
            let modeMenu = NSMenu()
            for mode in RefineMode.allCases {
                let item = NSMenuItem(title: mode.label, action: #selector(selectMode(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = mode.rawValue
                item.state = (mode == refineMode) ? .on : .off
                modeMenu.addItem(item)
            }
            let modeItem = NSMenuItem(title: "AI整形モード", action: nil, keyEquivalent: "")
            menu.setSubmenu(modeMenu, for: modeItem)
            menu.addItem(modeItem)
        }

        if !lastText.isEmpty {
            menu.addItem(.separator())
            let copy = NSMenuItem(title: "直近の書き起こしをコピー", action: #selector(copyLast), keyEquivalent: "c")
            copy.target = self
            menu.addItem(copy)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "\(config.appName) を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc func toggleRecording() {
        if state == .recording {
            endRecordingAndTranscribe()
        } else {
            beginRecording()
        }
        rebuildMenu()
    }

    @objc func selectMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = RefineMode(rawValue: raw) {
            refineMode = mode
            rebuildMenu()
        }
    }

    @objc func copyLast() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lastText, forType: .string)
    }

    func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = config.appName
        alert.informativeText = message
        alert.runModal()
    }
}
