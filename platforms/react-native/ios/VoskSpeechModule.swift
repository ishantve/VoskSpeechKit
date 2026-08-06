//
//  VoskSpeechModule.swift
//  vosk-speech-kit (React Native bridge)
//
//  Thin RCTEventEmitter over VoskSpeechKit. JS calls loadModel/start/stop/unload;
//  partial and final transcripts arrive as events. Audio capture is handled by the
//  kit's iOS VoskSpeechSession.
//

import Foundation
import React
import VoskSpeechKit

@objc(VoskSpeechModule)
final class VoskSpeechModule: RCTEventEmitter {

    private var model: VoskSpeechModel?
    private var session: VoskSpeechSession?
    private var hasListeners = false

    override static func requiresMainQueueSetup() -> Bool { false }

    override func supportedEvents() -> [String]! {
        ["onPartialResult", "onResult", "onError"]
    }

    override func startObserving() { hasListeners = true }
    override func stopObserving() { hasListeners = false }

    /// Load a Vosk model directory (host-provided path). Resolves the model info.
    @objc(loadModel:resolver:rejecter:)
    func loadModel(_ path: String,
                   resolver resolve: RCTPromiseResolveBlock,
                   rejecter reject: RCTPromiseRejectBlock) {
        do {
            let loaded = try VoskSpeechModel(path: path)
            model = loaded
            resolve(loaded.info.map(Self.dict) ?? ["path": path])
        } catch {
            reject("model_load_failed", "\(error)", error)
        }
    }

    /// Auto-pick and load the highest-version model under `modelsRoot`. Drop a new
    /// model (e.g. atc-lgraph-v11) into that folder and this just picks it up.
    @objc(loadLatestModel:resolver:rejecter:)
    func loadLatestModel(_ modelsRoot: String,
                         resolver resolve: RCTPromiseResolveBlock,
                         rejecter reject: RCTPromiseRejectBlock) {
        guard let info = VoskModelLocator(modelsRootPath: modelsRoot).latest() else {
            reject("no_model", "No Vosk model found under \(modelsRoot)", nil); return
        }
        do {
            model = try VoskSpeechModel(info: info)
            resolve(Self.dict(info))
        } catch {
            reject("model_load_failed", "\(error)", error)
        }
    }

    /// List every model discovered under `modelsRoot` (name / version / engine).
    @objc(availableModels:resolver:rejecter:)
    func availableModels(_ modelsRoot: String,
                         resolver resolve: RCTPromiseResolveBlock,
                         rejecter reject: RCTPromiseRejectBlock) {
        resolve(VoskModelLocator(modelsRootPath: modelsRoot).availableModels().map(Self.dict))
    }

    /// The vendored Vosk engine version.
    @objc(engineVersion:rejecter:)
    func engineVersion(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
        resolve(VoskEngine.version)
    }

    private static func dict(_ i: VoskModelInfo) -> [String: Any] {
        ["path": i.path, "name": i.name, "version": i.version,
         "voskEngineVersion": i.voskEngineVersion, "sampleRate": i.sampleRate,
         "source": i.source.rawValue, "displayName": i.displayName]
    }

    /// Start microphone recognition, optionally restricted to a phrase grammar.
    @objc(start:resolver:rejecter:)
    func start(_ grammar: [String]?,
               resolver resolve: RCTPromiseResolveBlock,
               rejecter reject: RCTPromiseRejectBlock) {
        guard let model else {
            reject("no_model", "Call loadModel() before start()", nil)
            return
        }
        do {
            let words = (grammar?.isEmpty == false) ? grammar : nil
            let session = try VoskSpeechSession(model: model, grammar: words)
            session.onPartial = { [weak self] in self?.emit("onPartialResult", $0.value) }
            session.onResult  = { [weak self] in self?.emit("onResult", $0.value) }
            session.onError   = { [weak self] in self?.emit("onError", "\($0)") }
            try session.start()
            self.session = session
            resolve(true)
        } catch {
            reject("start_failed", "\(error)", error)
        }
    }

    @objc(stop)
    func stop() { session?.stop(); session = nil }

    @objc(unload)
    func unload() { session?.stop(); session = nil; model = nil }

    private func emit(_ name: String, _ body: String) {
        guard hasListeners else { return }
        sendEvent(withName: name, body: body)
    }
}
