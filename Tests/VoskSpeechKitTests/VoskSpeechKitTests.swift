import XCTest
@testable import VoskSpeechKit

final class VoskSpeechKitTests: XCTestCase {

    func testTranscriptParsesFinalText() {
        let t = VoskTranscript(json: #"{"text":"cleared to land"}"#)
        XCTAssertEqual(t.text, "cleared to land")
        XCTAssertEqual(t.value, "cleared to land")
        XCTAssertNil(t.partial)
        XCTAssertFalse(t.isEmpty)
    }

    func testTranscriptParsesPartial() {
        let t = VoskTranscript(json: #"{"partial":"cleared to"}"#)
        XCTAssertEqual(t.partial, "cleared to")
        XCTAssertEqual(t.value, "cleared to")
        XCTAssertNil(t.text)
    }

    func testTranscriptEmptyOnGarbage() {
        XCTAssertTrue(VoskTranscript(json: "not json").isEmpty)
        XCTAssertTrue(VoskTranscript(json: "{}").isEmpty)
    }

    func testErrorDescriptionIncludesPath() {
        XCTAssertTrue(VoskError.modelLoadFailed("/tmp/model").description.contains("/tmp/model"))
    }

    // MARK: Model discovery

    func testFolderNameParsing() {
        XCTAssertEqual(VoskModelInfo.parseFolderName("atc-lgraph-v11").name, "atc-lgraph")
        XCTAssertEqual(VoskModelInfo.parseFolderName("atc-lgraph-v11").version, "11")
        XCTAssertEqual(VoskModelInfo.parseFolderName("atc-lgraph-v10").version, "10")
        XCTAssertEqual(VoskModelInfo.parseFolderName("model_v1.2").version, "1.2")
        XCTAssertEqual(VoskModelInfo.parseFolderName("model_v1.2").name, "model")
        XCTAssertEqual(VoskModelInfo.parseFolderName("plain").version, "0")
    }

    func testVersionCompareIsNumericNotLexical() {
        XCTAssertGreaterThan(VoskModelInfo.compareVersions("11", "10"), 0)
        XCTAssertLessThan(VoskModelInfo.compareVersions("9", "10"), 0)      // "9" < "10" numerically
        XCTAssertLessThan(VoskModelInfo.compareVersions("1.2", "1.10"), 0)  // component 2 < 10
        XCTAssertEqual(VoskModelInfo.compareVersions("11", "11"), 0)
    }

    func testLatestPicksHighestVersion() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vosk-test-\(UUID().uuidString)")
        let fm = FileManager.default
        for v in ["9", "10", "11"] {
            let dir = root.appendingPathComponent("atc-lgraph-v\(v)")
            try fm.createDirectory(at: dir.appendingPathComponent("am"), withIntermediateDirectories: true)
            try fm.createDirectory(at: dir.appendingPathComponent("conf"), withIntermediateDirectories: true)
        }
        defer { try? fm.removeItem(at: root) }

        let locator = VoskModelLocator(modelsRoot: root)
        XCTAssertEqual(locator.availableModels().count, 3)
        XCTAssertEqual(locator.latest()?.version, "11")
        XCTAssertEqual(locator.latest()?.name, "atc-lgraph")
        XCTAssertEqual(locator.model(named: "atc-lgraph")?.version, "11")
    }

    func testBundledModelDiscoveredAndLoads() throws {
        // The model dropped into Sources/VoskSpeechKit/Models is discovered…
        let info = try XCTUnwrap(VoskModelLocator.bundled?.latest(),
                                 "No bundled model found — is one in VoskSpeechKit/Models?")
        XCTAssertEqual(info.name, "atc-lgraph")
        XCTAssertEqual(info.version, "10")
        XCTAssertEqual(info.source, .folderName)

        // …and actually loads through Vosk (proves it's read + usable from here).
        let model = try VoskSpeechModel.bundledLatest()
        XCTAssertEqual(model.info?.version, "10")
    }

    func testManifestOverridesFolderName() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vosk-test-\(UUID().uuidString)")
        let fm = FileManager.default
        let dir = root.appendingPathComponent("some-folder")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let manifest = #"{"name":"atc-lgraph","version":"12","voskEngineVersion":"0.3.45","sampleRate":16000}"#
        try manifest.write(to: dir.appendingPathComponent("vosk-model.json"), atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: root) }

        let info = try XCTUnwrap(VoskModelLocator(modelsRoot: root).latest())
        XCTAssertEqual(info.version, "12")
        XCTAssertEqual(info.name, "atc-lgraph")
        XCTAssertEqual(info.voskEngineVersion, "0.3.45")
        XCTAssertEqual(info.source, .manifest)
    }
}
