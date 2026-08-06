#!/usr/bin/env bash
# Builds VoskSpeechFFI.xcframework (device + simulator static libs) from the SPM
# FFI target and drops it into the Unity plugin folder. Run this once (and after
# changing anything in Sources/VoskSpeechFFI or the Swift core) before shipping the
# Unity package. Requires Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD=.build/ffi-xcframework
rm -rf "$BUILD"; mkdir -p "$BUILD"

for SDK in iphoneos iphonesimulator; do
  echo "→ building VoskSpeechFFI for $SDK"
  xcodebuild build \
    -scheme VoskSpeechFFI \
    -sdk "$SDK" \
    -configuration Release \
    -derivedDataPath "$BUILD/$SDK" \
    SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
done

# The SPM static archive + generated Swift header for each slice.
DEVICE="$BUILD/iphoneos/Build/Products/Release-iphoneos"
SIM="$BUILD/iphonesimulator/Build/Products/Release-iphonesimulator"

xcodebuild -create-xcframework \
  -library "$DEVICE/libVoskSpeechFFI.a" \
  -library "$SIM/libVoskSpeechFFI.a" \
  -output "$BUILD/VoskSpeechFFI.xcframework"

DEST="platforms/unity/Runtime/Plugins/iOS/VoskSpeechFFI.xcframework"
rm -rf "$DEST"
cp -R "$BUILD/VoskSpeechFFI.xcframework" "$DEST"
echo "✓ wrote $DEST"
