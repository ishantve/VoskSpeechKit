# iOS native plugins

This folder must contain two xcframeworks for the Unity iOS build to link:

- `libvosk.xcframework` — the native Vosk engine (checked in here).
- `VoskSpeechFFI.xcframework` — the `@_cdecl` C ABI over VoskSpeechKit that the C#
  `DllImport("__Internal")` calls bind to. **Generate it** by running, from the
  repo root:

  ```sh
  ./scripts/build-ffi-xcframework.sh
  ```

  It is not committed because it is a build artifact of `Sources/VoskSpeechFFI`.

The acoustic model (e.g. `atc-lgraph-v10`, ~311 MB) is NOT shipped in the package —
place it under `StreamingAssets/` (or download at runtime) and pass its on-device
path to `new VoskModel(path)`.
