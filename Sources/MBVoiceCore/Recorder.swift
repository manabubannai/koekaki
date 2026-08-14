import AVFoundation

final class Recorder {
    private var recorder: AVAudioRecorder?
    private(set) var fileURL: URL?

    static func requestPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mbvoice-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        guard r.record() else {
            throw NSError(domain: "MBVoice", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "マイクにアクセスできません(システム設定→プライバシー→マイク)"])
        }
        recorder = r
        fileURL = url
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        return fileURL
    }
}
