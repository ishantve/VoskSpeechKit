require "json"
package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "vosk-speech-kit"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["repository"]
  s.license      = "Apache-2.0"
  s.authors      = { "Ishant" => "ishant@zibaltech.com" }
  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "https://github.com/ishantve/VoskSpeechKit.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"
  s.requires_arc = true

  # The React Native bridge; the Swift core (which vendors libvosk) is the sibling
  # VoskSpeechKit pod.
  s.dependency "React-Core"
  s.dependency "VoskSpeechKit"
end
