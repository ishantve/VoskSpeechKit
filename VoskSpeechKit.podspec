Pod::Spec.new do |s|
  s.name             = 'VoskSpeechKit'
  s.version          = '0.1.0'
  s.summary          = 'Offline Vosk speech-to-text — one Swift core for iOS, React Native, and Unity.'
  s.description      = <<-DESC
    A cross-platform wrapper around the Vosk offline speech-recognition engine.
    Feed 16 kHz mono PCM (or use the built-in iOS microphone session) and read
    partial / final transcripts as JSON or a typed VoskTranscript.

    The acoustic model is supplied by the host app at a path (never bundled — Vosk
    models are hundreds of MB). This is the single Swift source of truth behind the
    native, React Native, and Unity integrations.
  DESC

  s.homepage         = 'https://github.com/ishantve/VoskSpeechKit'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Ishant' => 'ishant@zibaltech.com' }
  s.source           = { :git => 'https://github.com/ishantve/VoskSpeechKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version         = '5.9'

  # Swift core + the Vosk C header (folded into this pod's module — the Swift code
  # gates `import CVosk` behind canImport so the same source builds under SPM too).
  s.source_files        = 'Sources/VoskSpeechKit/**/*.swift', 'Sources/CVosk/include/vosk_api.h'
  s.public_header_files = 'Sources/CVosk/include/vosk_api.h'

  # Models dropped into the kit ship with it (git-ignored by default; commit via
  # git-lfs to bundle one). Under CocoaPods these land in the host bundle — pass
  # that path to VoskModelLocator(modelsRootPath:) (Bundle.module is SPM-only).
  s.resources = 'Sources/VoskSpeechKit/Models/**/*'

  # Native Vosk static library (arm64 device + arm64/x86_64 simulator).
  s.vendored_frameworks = 'Frameworks/libvosk.xcframework'
  s.frameworks          = 'AVFoundation', 'Accelerate'
  s.library             = 'c++'
  s.requires_arc        = true
end
