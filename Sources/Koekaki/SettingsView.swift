import SwiftUI

/// ショートカットキーの設定画面(メイン小窓からシートで開く)。
struct SettingsView: View {
    @Binding var hotKey: HotKeySetting
    @Environment(\.dismiss) private var dismiss
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("設定")
                .font(.headline)

            HStack {
                Text("録音の開始/停止")
                Spacer()
                Button(action: toggleRecording) {
                    Text(recording ? "キーを押してください…" : hotKey.displayString)
                        .font(.system(.body, design: .monospaced).bold())
                        .frame(minWidth: 110)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(recording ? Color.orange.opacity(0.25)
                                              : Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(recording ? Color.orange : Color.secondary.opacity(0.3)))
                }
                .buttonStyle(.plain)
            }

            Text(recording
                 ? "修飾キー(⌘⌥⌃⇧)と一緒に押します。Escでキャンセル"
                 : "どのアプリを使っていても、このキーで録音を開始/停止できます(Koekaki起動中のみ)")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("バグ報告")
                .font(.subheadline.bold())

            Text("不具合を見つけたら、下のボタンから教えてください。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("メールでバグを報告") {
                openBugReportMail()
            }

            Text("メールが開かない場合は manablog.ai@gmail.com へ直接お送りください")
                .font(.caption2)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Button("リセット (⌥Space)") {
                    stopRecordingKeys()
                    hotKey = .default
                }
                Spacer()
                Button("閉じる") {
                    stopRecordingKeys()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 268)
        .onDisappear { stopRecordingKeys() }
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
        アプリ: Koekaki v\(version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = "manablog.ai@gmail.com"
        comps.queryItems = [
            URLQueryItem(name: "subject", value: "【バグ報告】Koekaki v\(version)"),
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
