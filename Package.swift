// swift-tools-version: 5.9
import PackageDescription

// VoskSpeechKit — the single Swift source of truth for offline Vosk speech-to-text
// behind native iOS, React Native, and Unity integrations (mirrors ATCParserKit).
//
// Wraps Vosk's native C library (the vendored `libvosk` binary target) through the
// `CVosk` header module. The 311 MB acoustic model is NEVER bundled here — the host
// app supplies its path.
//
// iOS-only: the vendored libvosk.xcframework ships only iOS slices, so build/test
// with an iOS destination (xcodebuild), not `swift build` on macOS.
let package = Package(
    name: "VoskSpeechKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "VoskSpeechKit", targets: ["VoskSpeechKit"]),
        .library(name: "VoskSpeechFFI", targets: ["VoskSpeechFFI"]),
    ],
    targets: [
        // Native Vosk static library (arm64 device + arm64/x86_64 simulator).
        .binaryTarget(name: "libvosk", path: "Frameworks/libvosk.xcframework"),

        // Header-only module exposing vosk_api.h to Swift; symbols come from libvosk.
        .target(name: "CVosk"),

        // Swift core: VoskModel / VoskRecognizer (portable) + VoskSpeechSession (iOS mic).
        // Bundles the Models/ folder so imported models ship with the kit (Bundle.module).
        .target(
            name: "VoskSpeechKit",
            dependencies: ["CVosk", "libvosk"],
            resources: [.copy("Models")],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("Accelerate"),
                .linkedFramework("AVFoundation"),
            ]
        ),

        // C boundary (@_cdecl) for the Unity/C# integration — feeds raw PCM in,
        // returns result JSON out. Manual memory management lives only here.
        .target(name: "VoskSpeechFFI", dependencies: ["VoskSpeechKit"]),

        .testTarget(name: "VoskSpeechKitTests", dependencies: ["VoskSpeechKit"]),
    ]
)
