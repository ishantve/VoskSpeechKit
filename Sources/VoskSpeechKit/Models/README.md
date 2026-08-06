# Models

Drop each Vosk model in its own subdirectory here, e.g.:

```
Models/
  atc-lgraph-v10/   am/ conf/ graph/ …   (+ optional vosk-model.json)
  atc-lgraph-v11/   am/ conf/ graph/ …
```

These are bundled into the kit (SwiftPM `Bundle.module`), so any project that
imports VoskSpeechKit gets them. `VoskModelLocator.bundled?.latest()` auto-selects
the highest version — drop `atc-lgraph-v11/` in and it's used, no code change.

⚠️ Vosk models are hundreds of MB. They are git-ignored by default (see the repo
`.gitignore`). To ship a model WITH the kit in git, track it with git-lfs; otherwise
each developer/project drops the model folder in here locally.
