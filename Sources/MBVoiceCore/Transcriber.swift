import Foundation

final class Transcriber {
    /// mlx_whisper の場所。pipeline の venv を既定とし、MBVOICE_WHISPER 環境変数で上書き可。
    var whisperPath: String = {
        if let env = ProcessInfo.processInfo.environment["MBVOICE_WHISPER"], !env.isEmpty { return env }
        return NSString("~/Documents/pipeline/.venv/bin/mlx_whisper").expandingTildeInPath
    }()
    var model = "mlx-community/whisper-large-v3-turbo"

    func transcribe(_ audioURL: URL) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: whisperPath) else {
            throw NSError(domain: "MBVoice", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "mlx_whisper が見つかりません: \(whisperPath)"])
        }
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mbvoice-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outDir) }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: whisperPath)
        p.arguments = [
            audioURL.path,
            "--model", model,
            "--language", "ja",
            "--output-format", "txt",
            "--output-dir", outDir.path,
            "--output-name", "result",
            "--verbose", "False",
        ]
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["PATH"] = "\(home)/Documents/pipeline/.venv/bin:/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "")
        p.environment = env
        let errPipe = Pipe()
        p.standardError = errPipe
        p.standardOutput = Pipe()
        try p.run()
        p.waitUntilExit()

        guard p.terminationStatus == 0 else {
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "MBVoice", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "mlx_whisper エラー: \(err.suffix(200))"])
        }
        let resultURL = outDir.appendingPathComponent("result.txt")
        let text = (try? String(contentsOf: resultURL, encoding: .utf8)) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
