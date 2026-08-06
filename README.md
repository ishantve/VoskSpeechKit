# VoskSpeechKit

Offline speech-to-text built on [Vosk](https://alphacephei.com/vosk/) — **one Swift
core** wrapped for **native iOS (SPM & CocoaPods)**, **React Native**, and **Unity**.

Feed 16 kHz mono PCM (or use the built-in iOS microphone session) and read partial
and final transcripts.

---

## ⚠️ The model — read this first

Vosk acoustic models are **hundreds of MB**, so **VoskSpeechKit does not ship one**.
The repo only contains an empty `Sources/VoskSpeechKit/Models/` folder (with a
README). **You add the model yourself.**

1. Get a model — [Vosk model list](https://alphacephei.com/vosk/models), or your own
   (e.g. `atc-lgraph-v10`). Unzip it so the folder directly contains `am/`, `conf/`,
   `graph/`, …
2. Put it where your platform expects it (see each section below).
3. The kit loads it **by path** — nothing is downloaded or bundled automatically.

Optional `vosk-model.json` inside a model folder carries its metadata:
```json
{ "name": "atc-lgraph", "version": "11", "voskEngineVersion": "0.3.45", "sampleRate": 16000 }
```
Without it, the name/version are read from the folder name (`atc-lgraph-v11` → v11).
`VoskModelLocator` auto-selects the highest version in a folder.

---

## iOS — Swift Package Manager

```swift
// Package.swift
.package(url: "https://github.com/ishantve/VoskSpeechKit.git", from: "0.1.0")
```
or Xcode → File → Add Package Dependencies → paste the URL.

**Add the model** (choose one):
- **Local dev:** drop `atc-lgraph-v10/` into `Sources/VoskSpeechKit/Models/` — it is
  bundled via `Bundle.module`, and `VoskSpeechModel.bundledLatest()` finds it. (Only
  works when you build the package locally; a package fetched from git has no model.)
- **Any app:** ship the model in your app bundle / Documents and pass its path.

```swift
import VoskSpeechKit

// A) explicit path (recommended for shipping apps)
let model = try VoskSpeechModel(path: modelDirPath)
// B) auto-pick the highest version under a folder
let info  = VoskModelLocator(modelsRootPath: modelsDir).latest()!
let model = try VoskSpeechModel(info: info)

// Microphone → transcripts (iOS)
let session = try VoskSpeechSession(model: model)   // optional grammar: [String]
session.onPartial = { print("…", $0.value) }
session.onResult  = { print("✓", $0.value) }
try session.start(); /* … */ session.stop()

// Or feed your own 16 kHz mono Int16 PCM (any platform)
let rec = try VoskSpeechRecognizer(model: model, sampleRate: 16_000)
_ = rec.acceptWaveform(int16Samples); print(rec.result.value)
```

> iOS only: `libvosk.xcframework` ships iOS slices, so build/test with an iOS
> destination, not `swift build` on macOS.

---

## iOS — CocoaPods

```ruby
# Podfile
pod 'VoskSpeechKit', :git => 'https://github.com/ishantve/VoskSpeechKit.git', :tag => '0.1.0'
```
```sh
pod install
```
The model is not in the pod — ship it in your app bundle and pass the path to
`VoskSpeechModel(path:)`. (`Bundle.module` is SPM-only; under CocoaPods always use an
explicit path.) Usage is the same Swift API as above.

---

## React Native — npm

```sh
npm install vosk-speech-kit
cd ios && pod install
```
In the app's **Podfile**, add the native core (the npm package is the JS + bridge; the
Swift core that vendors `libvosk` is the sibling pod):
```ruby
pod 'VoskSpeechKit', :git => 'https://github.com/ishantve/VoskSpeechKit.git', :tag => '0.1.0'
```

**Add the model:** bundle it with your iOS app (drag the `atc-lgraph-v10/` folder into
the Xcode project as a *folder reference*), then pass its on-device path:
```ts
import VoskSpeech from 'vosk-speech-kit';
import { MainBundlePath } from 'react-native-fs';

// pick the newest model under a folder, or pass an exact path with loadModel()
const info = await VoskSpeech.loadLatestModel(`${MainBundlePath}/Models`);
console.log('loaded', info.displayName);

const sub = VoskSpeech.onResult(t => console.log('result', t));
VoskSpeech.onPartialResult(t => console.log('partial', t));
await VoskSpeech.start(/* optional grammar: string[] */);
// …
VoskSpeech.stop();
sub.remove();
```
iOS only for now.

---

## Unity (iOS)

Add the package (Package Manager → Add from git URL):
```
https://github.com/ishantve/VoskSpeechKit.git?path=/platforms/unity
```
Generate the native FFI binary once (run from the repo root of a local checkout):
```sh
./scripts/build-ffi-xcframework.sh   # writes platforms/unity/Runtime/Plugins/iOS/VoskSpeechFFI.xcframework
```
`libvosk.xcframework` is already under `platforms/unity/Runtime/Plugins/iOS/`.

**Add the model:** place it under `Assets/StreamingAssets/Models/atc-lgraph-v10/`.
```csharp
using VoskSpeechKit;

string root = System.IO.Path.Combine(Application.streamingAssetsPath, "Models");
var info = VoskModels.Latest(root);                 // or a fixed path
using var model = new VoskModel(info.Value.path);
using var rec   = new VoskRecognizer(model, 16000f);
// feed 16 kHz mono Int16 PCM captured with UnityEngine.Microphone
if (rec.AcceptWaveform(samples)) Debug.Log(rec.Result());
```

---

## Versions

- `VoskEngine.version` (Swift) / `VoskEngine.Version()` (Unity) / `VoskSpeech.engineVersion()`
  (RN) — the vendored `libvosk` build.
- Model name/version come from the model's `vosk-model.json` or its folder name.

## License

Apache-2.0. Bundles the Vosk library (Apache-2.0, © Alpha Cephei Inc.).
