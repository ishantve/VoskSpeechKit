//
//  VoskModelDiscovery.swift
//  VoskSpeechKit
//
//  Makes models drop-in upgradeable. Point a VoskModelLocator at a folder of model
//  directories; it auto-selects the highest version. Each model's name/version come
//  from an optional `vosk-model.json` manifest, or are derived from the directory
//  name (e.g. "atc-lgraph-v11" → name "atc-lgraph", version "11"). Drop v11 next to
//  v10 and `.latest()` picks it up — no code change.
//

import Foundation

/// The vendored Vosk engine (libvosk) version. This is metadata only — Vosk's C API
/// does not report its version at runtime — so update it whenever you replace
/// `Frameworks/libvosk.xcframework`. The authoritative per-model value is the
/// manifest's `voskEngineVersion` (the engine a given model was built against).
public enum VoskEngine {
    public static let version = "0.3 (react-native-vosk 2.1.7 build)"
}

/// Optional `vosk-model.json` shipped inside a model directory.
public struct VoskModelManifest: Decodable, Equatable {
    public let name: String
    public let version: String
    public let voskEngineVersion: String?
    public let sampleRate: Double?
}

/// Resolved, displayable metadata for one model directory.
public struct VoskModelInfo: Equatable {
    public enum Source: String, Equatable { case manifest, folderName }

    public let path: String            // the model directory
    public let name: String            // e.g. "atc-lgraph"
    public let version: String         // e.g. "11"
    public let voskEngineVersion: String   // manifest value, else VoskEngine.version
    public let sampleRate: Double      // defaults to 16000
    public let source: Source          // where name/version came from

    /// A one-line label, e.g. "atc-lgraph v11 · Vosk 0.3…".
    public var displayName: String { "\(name) v\(version) · Vosk \(voskEngineVersion)" }

    /// Resolve a single directory, or nil if it isn't a Vosk model.
    public static func resolve(directory: URL) -> VoskModelInfo? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else { return nil }

        // 1) Prefer an explicit manifest.
        let manifestURL = directory.appendingPathComponent("vosk-model.json")
        if let data = try? Data(contentsOf: manifestURL),
           let m = try? JSONDecoder().decode(VoskModelManifest.self, from: data) {
            return VoskModelInfo(path: directory.path,
                                 name: m.name,
                                 version: m.version,
                                 voskEngineVersion: m.voskEngineVersion ?? VoskEngine.version,
                                 sampleRate: m.sampleRate ?? 16_000,
                                 source: .manifest)
        }

        // 2) Fall back to the folder name — but only if it really looks like a Vosk
        //    model (Kaldi layout has `am/` + `conf/`), so we don't pick up stray dirs.
        let looksLikeModel = fm.fileExists(atPath: directory.appendingPathComponent("am").path)
            && fm.fileExists(atPath: directory.appendingPathComponent("conf").path)
        guard looksLikeModel else { return nil }

        let (name, version) = parseFolderName(directory.lastPathComponent)
        return VoskModelInfo(path: directory.path,
                             name: name,
                             version: version,
                             voskEngineVersion: VoskEngine.version,
                             sampleRate: 16_000,
                             source: .folderName)
    }

    /// "atc-lgraph-v11" → ("atc-lgraph", "11");  "model_v1.2" → ("model", "1.2").
    static func parseFolderName(_ folder: String) -> (name: String, version: String) {
        let pattern = "^(.*?)[-_]v?([0-9]+(?:\\.[0-9]+)*)$"
        if let re = try? NSRegularExpression(pattern: pattern),
           let match = re.firstMatch(in: folder, range: NSRange(folder.startIndex..., in: folder)),
           let nameRange = Range(match.range(at: 1), in: folder),
           let versionRange = Range(match.range(at: 2), in: folder) {
            return (String(folder[nameRange]), String(folder[versionRange]))
        }
        return (folder, "0")
    }

    /// Numeric, component-wise version compare so "11" > "10" > "9" (not lexical).
    /// Returns <0, 0, >0.
    static func compareVersions(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<Swift.max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
}

/// Discovers models under a root folder and selects one. Drop a new model directory
/// in and `latest()` picks the highest version automatically.
public struct VoskModelLocator {
    public let modelsRoot: URL

    public init(modelsRoot: URL) { self.modelsRoot = modelsRoot }
    public init(modelsRootPath: String) { self.modelsRoot = URL(fileURLWithPath: modelsRootPath, isDirectory: true) }

    /// Every valid Vosk model directly under `modelsRoot`.
    public func availableModels() -> [VoskModelInfo] {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(at: modelsRoot,
                                                   includingPropertiesForKeys: [.isDirectoryKey],
                                                   options: [.skipsHiddenFiles])) ?? []
        return entries.compactMap { VoskModelInfo.resolve(directory: $0) }
    }

    /// The highest-version model found (any name), or nil if none.
    public func latest() -> VoskModelInfo? {
        availableModels().max { VoskModelInfo.compareVersions($0.version, $1.version) < 0 }
    }

    /// The highest-version model with the given name (e.g. "atc-lgraph").
    public func model(named name: String) -> VoskModelInfo? {
        availableModels()
            .filter { $0.name == name }
            .max { VoskModelInfo.compareVersions($0.version, $1.version) < 0 }
    }

    /// Locator over the models bundled inside the kit (Sources/VoskSpeechKit/Models,
    /// shipped via SwiftPM `Bundle.module`). nil under CocoaPods, where resources
    /// live in the host bundle — pass that path to `init(modelsRootPath:)` instead.
    public static var bundled: VoskModelLocator? {
        #if SWIFT_PACKAGE
        guard let root = Bundle.module.resourceURL?.appendingPathComponent("Models") else { return nil }
        return VoskModelLocator(modelsRoot: root)
        #else
        return nil
        #endif
    }
}

public extension VoskSpeechModel {
    /// Load the highest-version model bundled inside the kit. Drop a model into
    /// Sources/VoskSpeechKit/Models and this "just works" for any importer.
    static func bundledLatest() throws -> VoskSpeechModel {
        guard let info = VoskModelLocator.bundled?.latest() else {
            throw VoskError.modelLoadFailed("no bundled model in VoskSpeechKit/Models")
        }
        return try VoskSpeechModel(info: info)
    }
}
