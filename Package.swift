// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MBVoice",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "MBVoiceCore"),
        .executableTarget(name: "MBVoiceV1", dependencies: ["MBVoiceCore"]),
        .executableTarget(name: "MBVoiceV2", dependencies: ["MBVoiceCore"]),
        // whisper.cpp(vendor/whisper)の静的ライブラリを直接リンクする
        .systemLibrary(name: "CWhisper", path: "Sources/CWhisper"),
        .executableTarget(
            name: "Koekaki",
            dependencies: ["CWhisper"],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-Ivendor/whisper/include"]),
            ],
            linkerSettings: [
                .unsafeFlags(["-Lvendor/whisper/lib"]),
                .linkedLibrary("whisper"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
                .linkedLibrary("ggml-cpu"),
                .linkedLibrary("ggml-blas"),
                .linkedLibrary("ggml-metal"),
                .linkedLibrary("c++"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Foundation"),
            ]
        ),
    ]
)
