# @ishant89/vosk-speech-kit (React Native)

Offline Vosk speech-to-text for React Native (iOS). Thin bridge over the native
[VoskSpeechKit](https://github.com/ishantve/VoskSpeechKit) Swift core.

## Install
```sh
npm install @ishant89/vosk-speech-kit
cd ios && pod install
```
Add the native core to your app's **Podfile** (it vendors `libvosk`):
```ruby
pod 'VoskSpeechKit', :git => 'https://github.com/ishantve/VoskSpeechKit.git', :tag => '0.1.0'
```

## Add the model (required)
The model is not shipped. Bundle it with your iOS app:
1. Get a model (https://alphacephei.com/vosk/models), unzip so it has `am/ conf/ graph/`.
2. Drag the `atc-lgraph-v10/` folder into your Xcode project as a **folder reference**
   (blue folder), e.g. under a `Models/` group.
3. At runtime, resolve its on-device path and load it.

## Usage
```ts
import VoskSpeech from '@ishant89/vosk-speech-kit';
import { MainBundlePath } from 'react-native-fs';

const info = await VoskSpeech.loadLatestModel(`${MainBundlePath}/Models`); // or loadModel(exactPath)
VoskSpeech.onPartialResult(t => console.log('partial', t));
const sub = VoskSpeech.onResult(t => console.log('result', t));
await VoskSpeech.start();           // optional grammar: string[]
// …
VoskSpeech.stop();
sub.remove();
```
API: `loadModel`, `loadLatestModel`, `availableModels`, `engineVersion`, `start`,
`stop`, `unload`, `onPartialResult`, `onResult`, `onError`. iOS only for now.
