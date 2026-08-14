// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MBVoice",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "MBVoiceCore"),
        .executableTarget(name: "MBVoiceV1", dependencies: ["MBVoiceCore"]),
        .executableTarget(name: "MBVoiceV2", dependencies: ["MBVoiceCore"]),
        .executableTarget(name: "Koekaki"),
    ]
)
