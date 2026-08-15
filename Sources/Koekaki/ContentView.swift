import SwiftUI

/// ウィンドウを常に最前面(floating)にするためのヘルパー。
private struct FloatingWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.collectionBehavior.insert(.fullScreenAuxiliary)
            window.title = "Koekaki"
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @StateObject private var engine = WhisperEngine()
    @State private var copied = false
    @State private var hotKey = HotKeySetting.load()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gearshape").hidden()
                Spacer()
                Text("Koekaki")
                    .font(.headline)
                    .kerning(1)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("ショートカットキーの設定")
            }

            // 主役: 大きな録音ボタン(1クリックで開始、もう1クリックで停止→AI文字起こし→自動コピー)
            Button(action: handleTap) {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 96, height: 96)
                        .shadow(color: buttonColor.opacity(0.4),
                                radius: engine.state == .recording ? 14 : 6)
                    if engine.state == .transcribing {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    } else {
                        Image(systemName: engine.state == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(engine.state == .transcribing)

            Text(statusText)
                .font(.caption.bold())
                .foregroundColor(copied ? .green : .secondary)

            // 録音中のライブ認識テキスト / 直近の書き起こしを小さく確認(読み取り専用)
            ScrollView {
                Text(previewText.isEmpty ? "ここに文字が出ます" : previewText)
                    .font(.callout)
                    .foregroundColor(previewText.isEmpty ? Color.secondary.opacity(0.5) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 76)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
            .cornerRadius(8)

            if let error = engine.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(FloatingWindowConfigurator())
        .sheet(isPresented: $showSettings) {
            SettingsView(hotKey: $hotKey)
        }
        .onAppear {
            HotKeyCenter.shared.onPress = { handleTap() }
            HotKeyCenter.shared.apply(hotKey)
        }
        .onChange(of: hotKey) { newValue in
            newValue.save()
            HotKeyCenter.shared.apply(newValue)
        }
    }

    private var previewText: String { engine.transcript }

    private var buttonColor: Color {
        switch engine.state {
        case .recording: return .red
        case .transcribing: return .gray
        case .idle: return .orange
        }
    }

    private var statusText: String {
        switch engine.state {
        case .recording: return "録音中 \(engine.elapsed)秒 … クリックか \(hotKey.displayString) で停止"
        case .transcribing: return "AIが文字起こし中…"
        case .idle:
            if copied { return "コピーしました ⌘Vで貼り付け" }
            return "クリックか \(hotKey.displayString) で話す"
        }
    }

    private func handleTap() {
        switch engine.state {
        case .recording:
            engine.stop { text in
                guard !text.isEmpty else { return }
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { copied = false }
            }
        case .idle:
            // 新しい録音は前回のテキストをクリアして新規開始
            engine.transcript = ""
            copied = false
            engine.start()
        case .transcribing:
            break
        }
    }
}
