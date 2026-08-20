import SwiftUI

/// ウィンドウを常に最前面(floating)にするためのヘルパー。
private struct FloatingWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.collectionBehavior.insert(.fullScreenAuxiliary)
            window.title = "NoType"
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    /// 直近の書き起こしがどう届いたか(自動貼り付け or コピーのみ)。
    private enum Delivery { case pasted, copied }

    @StateObject private var engine = WhisperEngine()
    @State private var delivery: Delivery?
    @State private var hotKey = HotKeySetting.load()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "gearshape").hidden()
                Spacer()
                Text("notype")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .kerning(3)
                    .foregroundColor(NT.textPrimary)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(NT.textSecondary)
                }
                .buttonStyle(.plain)
                .help("設定")
            }

            // 主役: 大きな録音ボタン(1クリックで開始、もう1クリックで停止→文字起こし→自動貼り付け)
            Button(action: handleTap) {
                ZStack {
                    Circle()
                        .fill(buttonFill)
                        .frame(width: 92, height: 92)
                        .shadow(color: glowColor.opacity(0.55),
                                radius: engine.state == .recording ? 18 : 10)
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    if engine.state == .transcribing {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    } else {
                        Image(systemName: engine.state == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(engine.state == .transcribing)

            Text(statusText)
                .font(.caption.bold())
                .foregroundColor(delivery != nil && engine.state == .idle
                                 ? NT.accent : NT.textSecondary)

            // 直近の書き起こしを小さく確認(読み取り専用)
            ScrollView {
                Text(previewText.isEmpty ? "ここに文字が出ます" : previewText)
                    .font(.callout)
                    .foregroundColor(previewText.isEmpty ? NT.textSecondary.opacity(0.6) : NT.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 76)
            .padding(10)
            .background(NT.card)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NT.cardStroke, lineWidth: 1))

            if let error = engine.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(NT.recording)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(NT.background)
        .background(FloatingWindowConfigurator())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(hotKey: $hotKey)
        }
        .onAppear {
            HotKeyCenter.shared.onPress = { handleTap() }
            HotKeyCenter.shared.apply(hotKey)
            // 自動貼り付けに必要なアクセシビリティ許可を初回起動時に求めておく
            if Paster.autoPasteEnabled {
                Paster.ensureAccessibility(prompt: true)
            }
        }
        .onChange(of: hotKey) { newValue in
            newValue.save()
            HotKeyCenter.shared.apply(newValue)
        }
    }

    private var previewText: String { engine.transcript }

    private var buttonFill: AnyShapeStyle {
        switch engine.state {
        case .recording: return AnyShapeStyle(NT.recording)
        case .transcribing: return AnyShapeStyle(Color.white.opacity(0.15))
        case .idle: return AnyShapeStyle(NT.accentGradient)
        }
    }

    private var glowColor: Color {
        engine.state == .recording ? NT.recording : NT.accentDeep
    }

    private var statusText: String {
        switch engine.state {
        case .recording: return "録音中 \(engine.elapsed)秒 … もう一度 \(hotKey.displayString) で完了"
        case .transcribing: return "文字起こし中…"
        case .idle:
            switch delivery {
            case .pasted: return "貼り付けました"
            case .copied: return "コピーしました（⌘Vで貼り付け）"
            case nil: return "クリックか \(hotKey.displayString) で話す"
            }
        }
    }

    private func handleTap() {
        switch engine.state {
        case .recording:
            engine.stop { text in
                guard !text.isEmpty else { return }
                delivery = Paster.deliver(text) ? .pasted : .copied
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { delivery = nil }
            }
        case .idle:
            // 新しい録音は前回のテキストをクリアして新規開始
            engine.transcript = ""
            delivery = nil
            engine.start()
        case .transcribing:
            break
        }
    }
}
