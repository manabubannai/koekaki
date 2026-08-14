import SwiftUI

struct ContentView: View {
    @StateObject private var engine = SpeechEngine()
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("コエカキ")
                .font(.title2.bold())
                .kerning(2)
            Text("しゃべるだけでメモが書ける。録音データはどこにも保存されません。")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: { engine.toggle() }) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    Text(engine.listening ? "録音中… クリックで停止" : "クリックして話す")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(engine.listening ? Color.red : Color.orange)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Text(engine.interim)
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .lineLimit(2)

            TextEditor(text: $engine.transcript)
                .font(.system(size: 15))
                .lineSpacing(6)
                .padding(8)
                .frame(minHeight: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3))
                )

            if let error = engine.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack(spacing: 10) {
                Button(copied ? "コピーしました" : "コピー") {
                    guard !engine.transcript.isEmpty else { return }
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(engine.transcript, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }
                Button("クリア") {
                    engine.transcript = ""
                }
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 440, height: 580)
    }
}
