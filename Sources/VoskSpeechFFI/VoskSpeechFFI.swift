//
//  VoskSpeechFFI.swift
//  VoskSpeechKit
//
//  Flat C ABI (@_cdecl) over VoskSpeechKit for the Unity / C# integration. Unity
//  owns audio capture and feeds raw PCM here; results come back as JSON strings.
//
//  Ownership contract (this is the only place with manual memory management):
//   • vsk_model_new / vsk_recognizer_new return retained opaque handles — free them
//     with vsk_model_free / vsk_recognizer_free exactly once.
//   • The char* returned by the result functions is strdup'd — free it with
//     vsk_string_free exactly once.
//

import Foundation
import VoskSpeechKit

// MARK: - Model

@_cdecl("vsk_model_new")
public func vsk_model_new(_ path: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    guard let path, let model = try? VoskSpeechModel(path: String(cString: path)) else { return nil }
    return Unmanaged.passRetained(model).toOpaque()
}

@_cdecl("vsk_model_free")
public func vsk_model_free(_ handle: UnsafeMutableRawPointer?) {
    guard let handle else { return }
    Unmanaged<VoskSpeechModel>.fromOpaque(handle).release()
}

// MARK: - Recognizer

@_cdecl("vsk_recognizer_new")
public func vsk_recognizer_new(_ modelHandle: UnsafeMutableRawPointer?,
                               _ sampleRate: Float) -> UnsafeMutableRawPointer? {
    guard let modelHandle else { return nil }
    let model = Unmanaged<VoskSpeechModel>.fromOpaque(modelHandle).takeUnretainedValue()
    guard let recognizer = try? VoskSpeechRecognizer(model: model, sampleRate: sampleRate) else { return nil }
    return Unmanaged.passRetained(recognizer).toOpaque()
}

@_cdecl("vsk_recognizer_free")
public func vsk_recognizer_free(_ handle: UnsafeMutableRawPointer?) {
    guard let handle else { return }
    Unmanaged<VoskSpeechRecognizer>.fromOpaque(handle).release()
}

/// Feed `length` 16-bit mono samples. Returns 1 at an utterance boundary,
/// 0 mid-utterance, -1 on a bad handle.
@_cdecl("vsk_accept_waveform")
public func vsk_accept_waveform(_ handle: UnsafeMutableRawPointer?,
                                _ data: UnsafePointer<Int16>?,
                                _ length: Int32) -> Int32 {
    guard let handle, let data else { return -1 }
    let recognizer = Unmanaged<VoskSpeechRecognizer>.fromOpaque(handle).takeUnretainedValue()
    let samples = Array(UnsafeBufferPointer(start: data, count: Int(length)))
    return recognizer.acceptWaveform(samples) ? 1 : 0
}

@_cdecl("vsk_result")
public func vsk_result(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>? {
    copyOut(handle) { $0.resultJSON }
}

@_cdecl("vsk_partial_result")
public func vsk_partial_result(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>? {
    copyOut(handle) { $0.partialJSON }
}

@_cdecl("vsk_final_result")
public func vsk_final_result(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>? {
    copyOut(handle) { $0.finalJSON }
}

@_cdecl("vsk_reset")
public func vsk_reset(_ handle: UnsafeMutableRawPointer?) {
    guard let handle else { return }
    Unmanaged<VoskSpeechRecognizer>.fromOpaque(handle).takeUnretainedValue().reset()
}

/// Set global Vosk log verbosity (-1 silences).
@_cdecl("vsk_set_log_level")
public func vsk_set_log_level(_ level: Int32) { voskSetLogLevel(level) }

// MARK: - Discovery / versions

/// Vendored libvosk version string (strdup'd — free with vsk_string_free).
@_cdecl("vsk_engine_version")
public func vsk_engine_version() -> UnsafeMutablePointer<CChar>? { strdup(VoskEngine.version) }

/// JSON for the highest-version model under `root`, or null if none. The host
/// passes the returned `path` to vsk_model_new. Free the string with vsk_string_free.
@_cdecl("vsk_latest_model_json")
public func vsk_latest_model_json(_ root: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
    guard let root, let info = VoskModelLocator(modelsRootPath: String(cString: root)).latest() else { return nil }
    return strdup(infoJSON(info))
}

/// JSON array of every model under `root`. Free with vsk_string_free.
@_cdecl("vsk_available_models_json")
public func vsk_available_models_json(_ root: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
    guard let root else { return nil }
    let list = VoskModelLocator(modelsRootPath: String(cString: root)).availableModels().map(infoDict)
    guard let data = try? JSONSerialization.data(withJSONObject: list),
          let json = String(data: data, encoding: .utf8) else { return nil }
    return strdup(json)
}

/// Free a char* returned by any of the result / discovery functions.
@_cdecl("vsk_string_free")
public func vsk_string_free(_ ptr: UnsafeMutablePointer<CChar>?) { free(ptr) }

// MARK: - Helpers

private func infoDict(_ i: VoskModelInfo) -> [String: Any] {
    ["path": i.path, "name": i.name, "version": i.version,
     "voskEngineVersion": i.voskEngineVersion, "sampleRate": i.sampleRate,
     "source": i.source.rawValue, "displayName": i.displayName]
}

private func infoJSON(_ i: VoskModelInfo) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: infoDict(i)),
          let json = String(data: data, encoding: .utf8) else { return "{}" }
    return json
}

// MARK: - Helper

private func copyOut(_ handle: UnsafeMutableRawPointer?,
                     _ body: (VoskSpeechRecognizer) -> String) -> UnsafeMutablePointer<CChar>? {
    guard let handle else { return nil }
    let recognizer = Unmanaged<VoskSpeechRecognizer>.fromOpaque(handle).takeUnretainedValue()
    return strdup(body(recognizer))
}
