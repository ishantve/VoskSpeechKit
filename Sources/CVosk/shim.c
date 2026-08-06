// Intentionally empty. CVosk is a header-only module that re-exports Vosk's C
// API (see include/module.modulemap); the implementation symbols come from the
// vendored `libvosk` binary target. This file exists only so SwiftPM treats
// CVosk as a valid C target.
