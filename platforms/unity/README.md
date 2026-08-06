# VoskSpeechKit (Unity, iOS)

Offline Vosk speech-to-text for Unity iOS builds. C# binding over the native
VoskSpeechFFI C ABI.

## Install
Package Manager → Add package from git URL:
```
https://github.com/ishantve/VoskSpeechKit.git?path=/platforms/unity
```

## Build the native FFI (once)
From a local checkout of the repo root:
```sh
./scripts/build-ffi-xcframework.sh
```
This writes `platforms/unity/Runtime/Plugins/iOS/VoskSpeechFFI.xcframework`.
`libvosk.xcframework` is already committed alongside it.

## Add the model (required)
Not shipped with the package. Place it under:
```
Assets/StreamingAssets/Models/atc-lgraph-v10/    (am/ conf/ graph/ …)
```

## Usage
```csharp
using VoskSpeechKit;

string root  = System.IO.Path.Combine(Application.streamingAssetsPath, "Models");
var    info  = VoskModels.Latest(root);
using var model = new VoskModel(info.Value.path);
using var rec   = new VoskRecognizer(model, 16000f);
// feed 16 kHz mono Int16 PCM from UnityEngine.Microphone
if (rec.AcceptWaveform(samples)) Debug.Log(rec.Result());

Debug.Log(VoskEngine.Version());
```
iOS device/simulator only.
