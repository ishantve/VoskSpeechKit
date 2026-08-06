# VoskSpeechKit

Offline speech-to-text built on [Vosk](https://alphacephei.com/vosk/) — **one Swift
core** wrapped for **native iOS**, **React Native**, and **Unity**, the same way
[ATCParserKit](https://github.com/ishantve/ATCParserKit) ships one parser across
platforms.

Feed 16 kHz mono PCM (or use the built-in iOS microphone session) and read partial
and final transcripts. The acoustic model is **supplied by the host app at a path** —
it is never bundled (Vosk models are hundreds of MB).

## Layout

```
Sources/CVosk/            # Vosk C API as a Swift-importable module (SPM)
Sources/VoskSpeechKit/    # Swift core: VoskSpeechModel, VoskSpeechRecognizer, VoskSpeechSession (iOS mic)
Sources/VoskSpeechFFI/    # @_cdecl C ABI for Unity/C#
Frameworks/libvosk.xcframework   # vendored native Vosk engine (arm64 device + arm64/x86_64 sim)
platforms/react-native/   # RN bridge (pod + native module + TS API)
platforms/unity/          # Unity package (C# binding + iOS plugins)
scripts/                  # build-ffi-xcframework.sh
```

## Native iOS (Swift Package Manager / CocoaPods)

```swift
import VoskSpeechKit

let model = try VoskSpeechModel(path: modelDirPath)   // host-provided (e.g. atc-lgraph-v10)

// A) Microphone → transcripts (iOS convenience)
let session = try VoskSpeechSession(model: model)     // optional grammar: [String]
session.onPartial = { print("…", $0.value) }
session.onResult  = { print("✓", $0.value) }
try session.start()
// … later
session.stop()

// B) Portable: feed your own PCM (any platform)
let recognizer = try VoskSpeechRecognizer(model: model, sampleRate: 16_000)
if recognizer.acceptWaveform(int16Samples) { print(recognizer.result.value) }
else { print(recognizer.partial.value) }
```

> iOS only: `libvosk.xcframework` ships iOS slices, so build/test with an iOS
> destination (`xcodebuild -scheme VoskSpeechKit -destination 'platform=iOS Simulator,…'`),
> not `swift build` on macOS.

## React Native

```ts
import VoskSpeech from 'vosk-speech-kit';

await VoskSpeech.loadModel(modelPath);          // host-provided path
const sub = VoskSpeech.onResult(t => console.log('result', t));
VoskSpeech.onPartialResult(t => console.log('partial', t));
await VoskSpeech.start(/* optional grammar: string[] */);
// …
VoskSpeech.stop();
sub.remove();
```

`cd ios && pod install` — the `vosk-speech-kit` pod depends on the `VoskSpeechKit`
core pod (which vendors `libvosk`).

## Unity (iOS)

```csharp
using VoskSpeechKit;

using var model = new VoskModel(modelPath);       // e.g. StreamingAssets path
using var rec   = new VoskRecognizer(model, 16000f);
// feed 16 kHz mono Int16 PCM captured via UnityEngine.Microphone
if (rec.AcceptWaveform(samples)) Debug.Log(rec.Result());
else                             Debug.Log(rec.PartialResult());
```

Before shipping the Unity package, generate the FFI binary:

```sh
./scripts/build-ffi-xcframework.sh   # writes platforms/unity/Runtime/Plugins/iOS/VoskSpeechFFI.xcframework
```

## Models & versions (drop-in upgrades)

The acoustic model is **never bundled** (Vosk models are hundreds of MB). Ship it
with the app or download it, and keep every model in its own subdirectory under one
"models" folder:

```
Models/
  atc-lgraph-v10/   am/ conf/ graph/ …   (+ optional vosk-model.json)
  atc-lgraph-v11/   am/ conf/ graph/ …
```

**Getting `atc-lgraph-v11` from the team = drop the folder in and it just works.**
The kit auto-selects the highest version.

### Bundled inside the kit (self-contained)

Put models in the kit's own folder — **`Sources/VoskSpeechKit/Models/`** — and they
ship with the kit to every project that imports it (SwiftPM `Bundle.module`):

```swift
let model = try VoskSpeechModel.bundledLatest()   // highest version in VoskSpeechKit/Models
print(model.info?.displayName)                    // "atc-lgraph v11 · Vosk 0.3…"
```

> Models are git-ignored by default (hundreds of MB). To commit one WITH the kit,
> track it with git-lfs; otherwise each project drops the model folder in locally.
> `Bundle.module` is SwiftPM-only — under CocoaPods pass the host-bundle path to
> `VoskModelLocator(modelsRootPath:)`.

### Or any external folder

```swift
let info  = VoskModelLocator(modelsRootPath: modelsDir).latest()!   // → atc-lgraph v11
let model = try VoskSpeechModel(info: info)
```

### Where the two versions come from

| Version | Source | How to change |
|---|---|---|
| **Model** (e.g. `v11`) | the model's `vosk-model.json`, else derived from the folder name (`atc-lgraph-v11` → `11`) | ships with the model — nothing to edit |
| **Vosk engine** (e.g. `0.3…`) | `VoskEngine.version` constant | update when you replace `Frameworks/libvosk.xcframework` |

Optional per-model manifest (richest metadata — engine + sample rate travel with the
model, so nothing in the app needs editing on upgrade):

```json
// atc-lgraph-v11/vosk-model.json
{ "name": "atc-lgraph", "version": "11", "voskEngineVersion": "0.3.45", "sampleRate": 16000 }
```

If no manifest is present the name/version are read from the directory name, so a
plain `atc-lgraph-v11/` folder works too.

### Reading the versions in each platform

```swift
// iOS
VoskEngine.version                 // vendored engine
try VoskSpeechModel(info: info).info?.displayName
```
```ts
// React Native
const info = await VoskSpeech.loadLatestModel(modelsDir);  // { name, version, voskEngineVersion, … }
await VoskSpeech.engineVersion();
```
```csharp
// Unity
var info = VoskModels.Latest(modelsRoot);   // info?.displayName
VoskEngine.Version();
```

## License

Apache-2.0. Bundles the Vosk library (Apache-2.0, © Alpha Cephei Inc.).
