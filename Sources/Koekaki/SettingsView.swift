import SwiftUI

/// 設定画面(メイン小窓からシートで開く)。superwhisper風のセクション+カード構成。
struct SettingsView: View {
    @Binding var hotKey: HotKeySetting
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Paster.autoPasteKey) private var autoPaste = true
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("設定")
                    .font(.title3.bold())
                    .foregroundColor(NT.textPrimary)
                Spacer()
                Button("閉じる") {
                    stopRecordingKeys()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            section("キーボードショートカット") {
                row(title: "録音の開始 / 停止",
                    subtitle: recording
                        ? "修飾キー(⌘⌥⌃⇧)と一緒に押してください。Escで中止"
                        : "どのアプリを使っていても、このキーで話しはじめられます") {
                    HStack(spacing: 8) {
                        Button {
                            stopRecordingKeys()
                            hotKey = .default
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(NT.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("既定(⌥Space)に戻す")

                        Button(action: toggleRecording) {
                            if recording {
                                Text("キーを押してください…")
                                    .font(.caption.bold())
                                    .foregroundColor(NT.accent)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(NT.accent.opacity(0.15))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6)
                                        .stroke(NT.accent, lineWidth: 1))
                            } else {
                                keycaps
                            }
                        }
                        .buttonStyle(.plain)
                        .help("クリックして新しいキーを録音")
                    }
                }
            }

            section("貼り付け") {
                VStack(alignment: .leading, spacing: 10) {
                    row(title: "自動で貼り付け",
                        subtitle: "文字起こしが終わると、カーソル位置へそのまま入力されます") {
                        Toggle("", isOn: $autoPaste)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(NT.accent)
                    }
                    Text(autoPaste
                         ? "初回は「システム設定 → プライバシーとセキュリティ → アクセシビリティ」で NoType を許可してください"
                         : "オフの間はクリップボードにコピーされます（⌘Vで貼り付け）")
                        .font(.caption2)
                        .foregroundColor(NT.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            section("バグ報告") {
                VStack(alignment: .leading, spacing: 8) {
                    row(title: "不具合を見つけたら",
                        subtitle: "メールが開かない場合は manablog.ai@gmail.com へ直接どうぞ") {
                        Button("メールで報告") { openBugReportMail() }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(NT.bgBottom)
        .preferredColorScheme(.dark)
        .onDisappear { stopRecordingKeys() }
        .onChange(of: autoPaste) { on in
            if on { Paster.ensureAccessibility(prompt: true) }
        }
    }

    /// 現在のショートカットをキーキャップ風に並べて表示する。
    private var keycaps: some View {
        HStack(spacing: 4) {
            ForEach(keycapLabels, id: \.self) { cap in
                Text(cap)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(NT.textPrimary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 9)
                    .background(Color.white.opacity(0.10))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
        }
    }

    private var keycapLabels: [String] {
        var caps: [String] = []
        if hotKey.modifiers.contains(.control) { caps.append("⌃") }
        if hotKey.modifiers.contains(.option) { caps.append("⌥") }
        if hotKey.modifiers.contains(.shift) { caps.append("⇧") }
        if hotKey.modifiers.contains(.command) { caps.append("⌘") }
        caps.append(hotKey.label)
        return caps
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(NT.textSecondary)
                .textCase(nil)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NT.card)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(NT.cardStroke, lineWidth: 1))
        }
    }

    private func row<Trailing: View>(title: String, subtitle: String,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundColor(NT.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(NT.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }

    private func toggleRecording() {
        recording ? stopRecordingKeys() : startRecordingKeys()
    }

    private func startRecordingKeys() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                stopRecordingKeys()
                return nil
            }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let isFunctionKey = (96...122).contains(event.keyCode)
            // 修飾キーなしの文字キーは普段の入力を奪うので不可(F1〜F12のみ単独可)
            guard !mods.isEmpty || isFunctionKey else { return nil }
            hotKey = HotKeySetting(keyCode: event.keyCode, modifiers: mods,
                                   label: HotKeySetting.keyLabel(for: event))
            stopRecordingKeys()
            return nil
        }
    }

    private func openBugReportMail() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let body = """
        ■ どんな不具合ですか？
        （ここに書いてください）

        ■ 直前に何をしましたか？（再現手順）
        （ここに書いてください）

        ---
        アプリ: NoType v\(version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = "manablog.ai@gmail.com"
        comps.queryItems = [
            URLQueryItem(name: "subject", value: "【バグ報告】NoType v\(version)"),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func stopRecordingKeys() {
        recording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
