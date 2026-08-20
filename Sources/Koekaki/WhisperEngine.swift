import AVFoundation
import AppKit
import CWhisper

/// 同梱のwhisper(large-v3-turbo量子化)でローカル文字起こしする。
/// 録音中は16kHzモノラルにリサンプルしながらバッファに貯め、停止時に一括で認識する。
final class WhisperEngine: NSObject, ObservableObject {
    enum State { case idle, recording, transcribing }

    @Published var state: State = .idle
    @Published var transcript = ""
    @Published var elapsed: Int = 0
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private let sampleQueue = DispatchQueue(label: "koekaki.samples")
    private let whisperQueue = DispatchQueue(label: "koekaki.whisper", qos: .userInitiated)
    private var ctx: OpaquePointer?
    private var timer: Timer?
    private let language = strdup("ja")
    // superwhisper風の効果音(録音開始/停止)。システム音のPop/Bottleを控えめの音量で鳴らす
    private let startSound: NSSound? = {
        let s = NSSound(named: "Pop"); s?.volume = 0.6; return s
    }()
    private let stopSound: NSSound? = {
        let s = NSSound(named: "Bottle"); s?.volume = 0.6; return s
    }()

    func start() {
        guard state == .idle else { return }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    self.errorMessage = "マイクが許可されていません(システム設定→プライバシーとセキュリティ→マイク)"
                    return
                }
                self.beginSession()
            }
        }
        // 初回はモデルの読み込みに数秒かかるため、録音と並行して裏で先に読んでおく
        whisperQueue.async { _ = self.loadContext() }
    }

    func stop(completion: @escaping (String) -> Void) {
        guard state == .recording else { return }
        state = .transcribing
        timer?.invalidate()
        timer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        converter = nil
        stopSound?.stop()
        stopSound?.play()
        whisperQueue.async {
            let audio = self.sampleQueue.sync { self.samples }
            let text = self.transcribe(audio)
            DispatchQueue.main.async {
                self.state = .idle
                self.transcript = text
                completion(text)
            }
        }
    }

    private func beginSession() {
        do {
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000,
                                             channels: 1, interleaved: false),
                  let conv = AVAudioConverter(from: format, to: target) else {
                errorMessage = "マイク入力を初期化できませんでした"
                return
            }
            converter = conv
            sampleQueue.sync { samples = [] }
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                self?.append(buffer, to: target)
            }
            audioEngine.prepare()
            try audioEngine.start()
            state = .recording
            elapsed = 0
            errorMessage = nil
            startSound?.stop()
            startSound?.play()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.elapsed += 1
            }
        } catch {
            errorMessage = "録音を開始できませんでした: \(error.localizedDescription)"
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer, to target: AVAudioFormat) {
        guard let conv = converter else { return }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var fed = false
        var err: NSError?
        conv.convert(to: out, error: &err) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard err == nil, out.frameLength > 0, let ch = out.floatChannelData else { return }
        let chunk = Array(UnsafeBufferPointer(start: ch[0], count: Int(out.frameLength)))
        sampleQueue.async { self.samples.append(contentsOf: chunk) }
    }

    private func loadContext() -> OpaquePointer? {
        if let ctx { return ctx }
        guard let path = Bundle.main.path(forResource: "ggml-large-v3-turbo-q5_0", ofType: "bin")
                ?? devModelPath() else {
            DispatchQueue.main.async { self.errorMessage = "音声認識モデルが見つかりません(アプリが壊れています。再ダウンロードしてください)" }
            return nil
        }
        var params = whisper_context_default_params()
        params.use_gpu = true
        ctx = whisper_init_from_file_with_params(path, params)
        if ctx == nil {
            DispatchQueue.main.async { self.errorMessage = "音声認識モデルを読み込めませんでした" }
        }
        return ctx
    }

    /// swift run 等、.appの外から動かした時のための開発用フォールバック
    private func devModelPath() -> String? {
        let p = FileManager.default.currentDirectoryPath + "/Resources/models/ggml-large-v3-turbo-q5_0.bin"
        return FileManager.default.fileExists(atPath: p) ? p : nil
    }

    private func transcribe(_ audio: [Float]) -> String {
        guard audio.count > 8000 else { return "" } // 0.5秒未満は無視
        guard let ctx = loadContext() else { return "" }
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.language = UnsafePointer(language)
        params.n_threads = Int32(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))
        params.no_timestamps = true
        params.print_progress = false
        params.print_realtime = false
        params.print_special = false
        params.print_timestamps = false
        params.suppress_blank = true
        let status = audio.withUnsafeBufferPointer { buf in
            whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
        }
        guard status == 0 else { return "" }
        var text = ""
        for i in 0..<whisper_full_n_segments(ctx) {
            if let seg = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: seg)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
