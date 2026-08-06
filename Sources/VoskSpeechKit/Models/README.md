# Models

Vosk acoustic models are hundreds of MB, so they are **not committed** to this repo
(this folder is git-ignored except for this README). **Add your own model here.**

Drop each model in its own subdirectory:

```
Models/
  atc-lgraph-v10/   am/ conf/ graph/ …   (+ optional vosk-model.json)
  atc-lgraph-v11/   am/ conf/ graph/ …
```

Get a model from https://alphacephei.com/vosk/models (or use your own). Unzip so the
folder directly contains `am/`, `conf/`, `graph/`.

### How it's used per platform
- **SPM (local build):** a model placed here is bundled via `Bundle.module`;
  `VoskSpeechModel.bundledLatest()` / `VoskModelLocator.bundled` auto-picks the
  highest version. (A package fetched from git has an empty Models/ — then pass a path.)
- **CocoaPods / remote SPM / React Native / Unity:** the model is **not** in the
  package. Ship it in your app and pass its path (`VoskSpeechModel(path:)`,
  `VoskModelLocator(modelsRootPath:)`, RN `loadModel`/`loadLatestModel`, Unity
  `new VoskModel(path)`). See the repo README for per-platform steps.
