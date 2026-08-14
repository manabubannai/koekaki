import AVFoundation
import Speech

/// macOS標準の音声認識(SFSpeechRecognizer)でライブ文字起こしする。
/// 外部依存ゼロなので、そのまま配布できる。
final class SpeechEngine: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var interim = ""
    @Published var listening = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() {
        listening ? stop() : start()
    }

    func start() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.errorMessage = "音声認識が許可されていません(システム設定→プライバシーとセキュリティ→音声認識)"
                    return
                }
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.errorMessage = "マイクが許可されていません(システム設定→プライバシーとセキュリティ→マイク)"
                            return
                        }
                        self.beginSession()
                    }
                }
            }
        }
    }

    func stop() {
        listening = false
        if !interim.isEmpty {
            transcript += interim
            interim = ""
        }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func beginSession() {
        guard recognizer?.isAvailable == true else {
            errorMessage = "音声認識が今使えません。少し待ってからもう一度お試しください。"
            return
        }
        do {
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            startRecognitionRequest()
            listening = true
            errorMessage = nil
        } catch {
            errorMessage = "録音を開始できませんでした: \(error.localizedDescription)"
        }
    }

    /// 認識リクエストは1分程度で切れるため、切れたらマイクはそのままにリクエストだけ張り直す。
    private func startRecognitionRequest() {
        task?.cancel()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true
        }
        request = req
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    if result.isFinal {
                        self.transcript += result.bestTranscription.formattedString
                        self.interim = ""
                        if self.listening { self.startRecognitionRequest() }
                    } else {
                        self.interim = result.bestTranscription.formattedString
                    }
                }
                if error != nil, self.listening, self.audioEngine.isRunning {
                    if !self.interim.isEmpty {
                        self.transcript += self.interim
                        self.interim = ""
                    }
                    self.startRecognitionRequest()
                }
            }
        }
    }
}
