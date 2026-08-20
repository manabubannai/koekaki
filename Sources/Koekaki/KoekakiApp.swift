import SwiftUI
import Combine

/// superwhisper型のメニューバー常駐アプリ。メインウィンドウは持たない。
/// 初回起動時だけ設定ウィンドウを開き、以降はメニューバーとショートカットだけで完結する。
@main
struct KoekakiApp: App {
    @StateObject private var app = AppCoordinator()

    var body: some Scene {
        MenuBarExtra {
            Button(app.engine.state == .recording ? "録音を停止して貼り付け" : "録音を開始") {
                app.toggle()
            }
            .disabled(app.engine.state == .transcribing)
            Text("ショートカット: \(app.hotKey.displayString)")
            if app.engine.state == .transcribing {
                Text("文字起こし中…")
            }
            if let error = app.engine.errorMessage {
                Text(error)
            }
            Divider()
            Button("設定…") { app.openSettings() }
            Divider()
            Button("NoType を終了") { NSApp.terminate(nil) }
        } label: {
            switch app.engine.state {
            case .idle:
                Image(systemName: "mic.fill")
            case .recording:
                HStack(spacing: 3) {
                    Image(systemName: "record.circle.fill")
                    Text("\(app.engine.elapsed)s")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
            case .transcribing:
                Image(systemName: "waveform")
            }
        }
    }
}

/// アプリ全体の司令塔。ショートカット・録音トグル・設定ウィンドウを持つ。
final class AppCoordinator: ObservableObject {
    let engine = WhisperEngine()
    @Published var hotKey = HotKeySetting.load() {
        didSet {
            hotKey.save()
            HotKeyCenter.shared.apply(hotKey)
        }
    }

    private var cancellables: Set<AnyCancellable> = []
    private var settingsWindow: NSWindow?

    init() {
        // engineの状態変化(録音中の経過秒など)をメニューバーアイコンへ伝播させる
        engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        HotKeyCenter.shared.onPress = { [weak self] in self?.toggle() }
        HotKeyCenter.shared.apply(hotKey)

        // 自動貼り付けに必要なアクセシビリティ許可を初回起動時に求めておく
        if Paster.autoPasteEnabled {
            Paster.ensureAccessibility(prompt: true)
        }

        // インストール後の初回だけ設定ウィンドウを開き、使い方(ショートカット)を見せる
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "didOpenSettingsOnce") {
            defaults.set(true, forKey: "didOpenSettingsOnce")
            DispatchQueue.main.async { [weak self] in self?.openSettings() }
        }
    }

    func toggle() {
        switch engine.state {
        case .recording:
            engine.stop { text in
                guard !text.isEmpty else { return }
                Paster.deliver(text)
            }
        case .idle:
            engine.transcript = ""
            engine.start()
        case .transcribing:
            break
        }
    }

    func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsRoot(app: self))
            let window = NSWindow(contentViewController: hosting)
            window.title = "NoType"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

/// 設定ウィンドウのルート。coordinatorを観測してSettingsViewへBindingを渡す。
private struct SettingsRoot: View {
    @ObservedObject var app: AppCoordinator

    var body: some View {
        SettingsView(hotKey: $app.hotKey)
    }
}
