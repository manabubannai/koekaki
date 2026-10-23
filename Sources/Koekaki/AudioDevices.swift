import CoreAudio
import Foundation

/// CoreAudio の入力デバイスまわりの小さなヘルパー。
///
/// 背景: Bluetooth イヤホンのマイクを開くと、イヤホンは通話用プロファイル(HFP)へ切り替わり、
/// 再生音が 16kHz モノラルの電話品質に落ちる。しかも録音をやめても戻らないことがある
/// (2026-10-23 MOTIF II で確認。システムの入力を Mac 内蔵マイクへ戻した瞬間に 44.1kHz ステレオへ復帰した)。
/// そこで NoType は内蔵マイクで録音し、希望すればシステムの既定入力も内蔵マイクへ固定する。
enum AudioDevices {
    static let avoidBluetoothMicKey = "avoidBluetoothMic"          // NoType の録音は内蔵マイクで
    static let keepSystemMicBuiltInKey = "keepSystemMicBuiltIn"    // システムの既定入力も内蔵マイクへ固定

    static var avoidBluetoothMic: Bool {
        UserDefaults.standard.object(forKey: avoidBluetoothMicKey) as? Bool ?? true
    }
    static var keepSystemMicBuiltIn: Bool {
        UserDefaults.standard.object(forKey: keepSystemMicBuiltInKey) as? Bool ?? false
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private static func uint32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    static func name(of device: AudioObjectID) -> String {
        var addr = address(kAudioObjectPropertyName)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(device, &addr, 0, nil, &size, $0)
        }
        return status == noErr ? (value as String) : "?"
    }

    static func allDevices() -> [AudioObjectID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr
        else { return [] }
        return ids
    }

    static func inputChannels(of device: AudioObjectID) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let list = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        defer { list.deallocate() }
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, list) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func transportType(of device: AudioObjectID) -> UInt32 {
        uint32(device, kAudioDevicePropertyTransportType) ?? 0
    }

    static func isBluetooth(_ device: AudioObjectID) -> Bool {
        let t = transportType(of: device)
        return t == kAudioDeviceTransportTypeBluetooth || t == kAudioDeviceTransportTypeBluetoothLE
    }

    static var defaultInput: AudioObjectID? {
        guard let id = uint32(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice),
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    /// Mac 内蔵マイク(MacBook Pro Microphone 等)。無ければ nil(Mac mini + 外付けなど)
    static var builtInMic: AudioObjectID? {
        allDevices().first { transportType(of: $0) == kAudioDeviceTransportTypeBuiltIn && inputChannels(of: $0) > 0 }
    }

    /// NoType の録音に使うべき機器。既定入力が Bluetooth で、内蔵マイクがあり、設定が有効なら内蔵マイク。
    /// それ以外は nil(= システムの既定入力のまま)
    static var preferredRecordingDevice: AudioObjectID? {
        guard avoidBluetoothMic, let def = defaultInput, isBluetooth(def) else { return nil }
        return builtInMic
    }

    @discardableResult
    static func setDefaultInput(_ device: AudioObjectID) -> Bool {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var id = device
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                          UInt32(MemoryLayout<AudioObjectID>.size), &id) == noErr
    }
}

/// システムの既定入力が Bluetooth 機器に切り替わったら内蔵マイクへ戻す見張り。
/// NoType 以外のアプリ(Claude Code の音声入力など)が既定入力を開いても
/// イヤホンが通話モードに落ちないようにする。
final class MicGuard {
    static let shared = MicGuard()
    private var listening = false
    private var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                     mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: kAudioObjectPropertyElementMain)
    private lazy var block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.applyIfNeeded()
    }

    func update() {
        if AudioDevices.keepSystemMicBuiltIn {
            if !listening {
                AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address,
                                                    DispatchQueue.main, block)
                listening = true
            }
            applyIfNeeded()
        } else if listening {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address,
                                                   DispatchQueue.main, block)
            listening = false
        }
    }

    private func applyIfNeeded() {
        guard AudioDevices.keepSystemMicBuiltIn,
              let def = AudioDevices.defaultInput, AudioDevices.isBluetooth(def),
              let builtIn = AudioDevices.builtInMic, builtIn != def else { return }
        // 切り替え直後は機器一覧が落ち着いていないことがあるので少し待ってから
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard AudioDevices.keepSystemMicBuiltIn,
                  let now = AudioDevices.defaultInput, AudioDevices.isBluetooth(now) else { return }
            AudioDevices.setDefaultInput(builtIn)
        }
    }
}
