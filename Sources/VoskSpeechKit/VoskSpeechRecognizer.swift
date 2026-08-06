//
//  VoskSpeechRecognizer.swift
//  VoskSpeechKit
//
//  Portable, platform-agnostic Swift wrapper over Vosk's C API. Feed 16 kHz mono
//  PCM (Int16 or raw bytes) and read partial / final transcripts. This is the
//  single source of truth behind the native, React Native, and Unity layers.
//
//  The acoustic model is NEVER bundled — VoskSpeechModel(path:) loads whatever the
//  host app ships or downloads.
//

// Under SwiftPM the Vosk C API is its own `CVosk` module; under CocoaPods the same
// header is folded into this pod's module, so no import is needed there.
#if canImport(CVosk)
import CVosk
#endif
import Foundation

public enum VoskError: Error, CustomStringConvertible {
    case modelLoadFailed(String)
    case recognizerInitFailed

    public var description: String {
        switch self {
        case .modelLoadFailed(let path): return "Vosk model failed to load at \(path)"
        case .recognizerInitFailed:      return "Vosk recognizer failed to initialise"
        }
    }
}

/// Global Vosk log verbosity. -1 silences it (the default); 0+ is increasingly noisy.
public func voskSetLogLevel(_ level: Int32) { vosk_set_log_level(level) }

/// A loaded Vosk acoustic model. Expensive to create, cheap to share: load once
/// and reuse across recognizers. Thread-safe to hold; not to mutate.
public final class VoskSpeechModel {
    let handle: OpaquePointer

    /// Resolved metadata (name / version / engine) for this model, if determinable
    /// from a `vosk-model.json` manifest or the directory name. nil for an
    /// unrecognised layout.
    public let info: VoskModelInfo?

    /// - Parameter path: directory of the unpacked Vosk model (host-provided).
    public init(path: String) throws {
        guard let handle = vosk_model_new(path) else { throw VoskError.modelLoadFailed(path) }
        self.handle = handle
        self.info = VoskModelInfo.resolve(directory: URL(fileURLWithPath: path, isDirectory: true))
    }

    /// Load a model chosen via `VoskModelLocator`, keeping its resolved metadata.
    public convenience init(info: VoskModelInfo) throws {
        try self.init(path: info.path)
    }

    deinit { vosk_model_free(handle) }
}

/// A single recognition stream. Not thread-safe: confine one recognizer to one
/// queue (VoskSpeechSession does this for you).
public final class VoskSpeechRecognizer {
    private let handle: OpaquePointer
    private let model: VoskSpeechModel   // retained so it outlives this recognizer

    /// - Parameters:
    ///   - model: a loaded model.
    ///   - sampleRate: PCM sample rate you will feed (Vosk models are 16 kHz).
    ///   - grammar: optional list of phrases to restrict recognition to; nil = open.
    public init(model: VoskSpeechModel, sampleRate: Float = 16_000, grammar: [String]? = nil) throws {
        self.model = model
        let created: OpaquePointer?
        if let grammar, !grammar.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: grammar),
           let json = String(data: data, encoding: .utf8) {
            created = vosk_recognizer_new_grm(model.handle, sampleRate, json)
        } else {
            created = vosk_recognizer_new(model.handle, sampleRate)
        }
        guard let handle = created else { throw VoskError.recognizerInitFailed }
        self.handle = handle
    }

    deinit { vosk_recognizer_free(handle) }

    /// Include per-word timing/confidence in results.
    public func setWords(_ enabled: Bool) { vosk_recognizer_set_words(handle, enabled ? 1 : 0) }

    /// Return up to N ranked alternatives (0 = single best).
    public func setMaxAlternatives(_ n: Int32) { vosk_recognizer_set_max_alternatives(handle, n) }

    /// Feed 16-bit mono PCM samples. Returns true when Vosk detects an utterance
    /// boundary and a full `result` is available; false while mid-utterance.
    @discardableResult
    public func acceptWaveform(_ samples: [Int16]) -> Bool {
        samples.withUnsafeBufferPointer { buf in
            vosk_recognizer_accept_waveform_s(handle, buf.baseAddress, Int32(buf.count)) == 1
        }
    }

    /// Feed raw 16-bit little-endian mono PCM bytes.
    @discardableResult
    public func acceptWaveform(_ data: Data) -> Bool {
        data.withUnsafeBytes { raw in
            vosk_recognizer_accept_waveform(handle,
                                            raw.bindMemory(to: CChar.self).baseAddress,
                                            Int32(data.count)) == 1
        }
    }

    /// JSON for the most recent completed utterance (e.g. `{"text":"cleared to land"}`).
    public var resultJSON: String { Self.string(vosk_recognizer_result(handle)) }
    /// JSON for the in-progress utterance (e.g. `{"partial":"cleared to"}`).
    public var partialJSON: String { Self.string(vosk_recognizer_partial_result(handle)) }
    /// JSON flushing whatever remains, ending the current utterance.
    public var finalJSON: String { Self.string(vosk_recognizer_final_result(handle)) }

    /// Decoded convenience: the completed-utterance text.
    public var result: VoskTranscript { VoskTranscript(json: resultJSON) }
    /// Decoded convenience: the in-progress text.
    public var partial: VoskTranscript { VoskTranscript(json: partialJSON) }
    /// Decoded convenience: flush + end the utterance.
    public var final: VoskTranscript { VoskTranscript(json: finalJSON) }

    /// Discard state and start a fresh utterance.
    public func reset() { vosk_recognizer_reset(handle) }

    private static func string(_ ptr: UnsafePointer<CChar>?) -> String {
        guard let ptr else { return "" }
        return String(cString: ptr)
    }
}

/// Typed view over a Vosk result JSON. `text` is set on completed utterances,
/// `partial` on in-progress ones; `value` returns whichever is present.
public struct VoskTranscript: Decodable, Equatable {
    public let text: String?
    public let partial: String?

    public var value: String { text ?? partial ?? "" }
    public var isEmpty: Bool { value.isEmpty }

    public init(text: String? = nil, partial: String? = nil) {
        self.text = text
        self.partial = partial
    }

    public init(json: String) {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(VoskTranscript.self, from: data) else {
            self.init()
            return
        }
        self = decoded
    }
}
