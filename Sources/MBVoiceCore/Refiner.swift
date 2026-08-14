import Foundation

enum RefineMode: String, CaseIterable {
    case raw
    case clean
    case bullets
    case mail

    var label: String {
        switch self {
        case .raw: return "そのまま(AI整形なし)"
        case .clean: return "整形(フィラー除去・句読点)"
        case .bullets: return "箇条書きに整理"
        case .mail: return "メール文に整える"
        }
    }

    var prompt: String? {
        switch self {
        case .raw:
            return nil
        case .clean:
            return "以下は音声入力の書き起こしです。誤変換とフィラー(えー、あの、まあ等)を除去し、句読点と改行を整えて自然な日本語にしてください。内容の追加・要約・言い換えはしないこと。整形後の本文だけを出力:"
        case .bullets:
            return "以下は音声入力の書き起こしです。内容を漏らさず、簡潔な箇条書きに整理してください。箇条書きだけを出力:"
        case .mail:
            return "以下は音声入力の書き起こしです。内容を変えずに、丁寧で自然な日本語のメール本文に整えてください。宛名や署名は入れず、本文だけを出力:"
        }
    }
}

final class Refiner {
    var claudePath: String = {
        let candidates = [
            NSString("~/.local/bin/claude").expandingTildeInPath,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? candidates[0]
    }()

    /// 失敗したら元テキストをそのまま返す(書き起こしを失わないため)。
    func refine(_ text: String, mode: RefineMode) -> String {
        guard let prompt = mode.prompt else { return text }
        guard FileManager.default.isExecutableFile(atPath: claudePath) else { return text }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: claudePath)
        p.arguments = ["-p", "--model", "haiku", prompt + "\n\n" + text]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        p.environment = env
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = Pipe()
        p.standardInput = Pipe()  // 対話待ちにならないよう閉じる
        do {
            try p.run()
        } catch {
            return text
        }
        (p.standardInput as? Pipe)?.fileHandleForWriting.closeFile()

        // 最大60秒でタイムアウト
        let deadline = Date().addingTimeInterval(60)
        while p.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        if p.isRunning {
            p.terminate()
            return text
        }
        guard p.terminationStatus == 0 else { return text }
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let refined = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return refined.isEmpty ? text : refined
    }
}
