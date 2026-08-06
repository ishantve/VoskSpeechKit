//
//  VoskSpeechSession.swift
//  VoskSpeechKit
//
//  iOS convenience layer: captures the microphone with AVAudioEngine, converts to
//  the 16 kHz mono Int16 PCM Vosk expects, streams it into a VoskSpeechRecognizer,
//  and delivers partial / final transcripts on the main queue.
//
//  This is the only platform-specific piece. React Native and Unity feed PCM into
//  VoskSpeechRecognizer / the FFI directly and don't use this type.
//

#if os(iOS)
import AVFoundation
import Foundation

public final class VoskSpeechSession {

    /// In-progress transcript (fires often). Delivered on the main queue.
    public var onPartial: ((VoskTranscript) -> Void)?
    /// Completed-utterance transcript. Delivered on the main queue.
    public var onResult: ((VoskTranscript) -> Void)?
    /// Capture / conversion errors. Delivered on the main queue.
    public var onError: ((Error) -> Void)?

    public private(set) var isRunning = false

    private let recognizer: VoskSpeechRecognizer
    private let engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    // Vosk recognizers are not thread-safe; serialise all feeding here.
    private let recognitionQueue = DispatchQueue(label: "tech.zibal.VoskSpeechKit.recognition")

    public init(model: VoskSpeechModel, grammar: [String]? = nil) throws {
        self.recognizer = try VoskSpeechRecognizer(model: model, sampleRate: 16_000, grammar: grammar)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: 16_000, channels: 1, interleaved: true) else {
            throw VoskError.recognizerInitFailed
        }
        self.targetFormat = format
    }

    /// Configure the audio session, start the engine and begin streaming to Vosk.
    public func start() throws {
        guard !isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        // playAndRecord (not .record) so the host can still play feedback sounds
        // (e.g. push-to-talk beeps) while capturing; .measurement keeps STT clean.
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw VoskError.recognizerInitFailed
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4_096, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    /// Stop capture and flush the final transcript through `onResult`.
    public func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        recognitionQueue.async { [weak self] in
            guard let self else { return }
            let final = self.recognizer.final
            self.recognizer.reset()
            self.emit { self.onResult?(final) }
        }
    }

    // MARK: - Audio

    private func handle(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var convError: NSError?
        converter.convert(to: out, error: &convError) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let convError { emit { self.onError?(convError) }; return }
        guard let channel = out.int16ChannelData, out.frameLength > 0 else { return }
        let samples = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))

        recognitionQueue.async { [weak self] in
            guard let self else { return }
            if self.recognizer.acceptWaveform(samples) {
                let result = self.recognizer.result
                self.emit { self.onResult?(result) }
            } else {
                let partial = self.recognizer.partial
                self.emit { self.onPartial?(partial) }
            }
        }
    }

    private func emit(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}
#endif
