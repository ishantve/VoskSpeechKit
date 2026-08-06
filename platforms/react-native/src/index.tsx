import { NativeModules, NativeEventEmitter, type EmitterSubscription } from 'react-native';

const LINKING_ERROR =
  `The native module 'VoskSpeechModule' is not linked. Make sure the 'vosk-speech-kit' ` +
  `and 'VoskSpeechKit' pods are installed (cd ios && pod install) and the app was rebuilt.`;

const VoskSpeechModule = NativeModules.VoskSpeechModule
  ? NativeModules.VoskSpeechModule
  : new Proxy({}, { get() { throw new Error(LINKING_ERROR); } });

const emitter = new NativeEventEmitter(VoskSpeechModule);

export type VoskListener = (text: string) => void;

/** Resolved metadata for a Vosk model (from its manifest or directory name). */
export interface VoskModelInfo {
  path: string;
  name: string;              // e.g. "atc-lgraph"
  version: string;           // e.g. "11"
  voskEngineVersion: string; // engine the model targets / vendored engine
  sampleRate: number;
  source: 'manifest' | 'folderName';
  displayName: string;       // e.g. "atc-lgraph v11 · Vosk 0.3…"
}

/**
 * Offline Vosk speech-to-text. Load a model directory, start microphone
 * recognition, and subscribe to partial / final transcripts.
 */
export const VoskSpeech = {
  /** Load a specific Vosk model directory. Resolves the model's info. */
  loadModel(path: string): Promise<VoskModelInfo> {
    return VoskSpeechModule.loadModel(path);
  },

  /**
   * Auto-pick and load the highest-version model under `modelsRoot`. Drop a new
   * model (e.g. atc-lgraph-v11) into that folder and this picks it up — no code
   * change. Resolves the chosen model's info.
   */
  loadLatestModel(modelsRoot: string): Promise<VoskModelInfo> {
    return VoskSpeechModule.loadLatestModel(modelsRoot);
  },

  /** List every model discovered under `modelsRoot`. */
  availableModels(modelsRoot: string): Promise<VoskModelInfo[]> {
    return VoskSpeechModule.availableModels(modelsRoot);
  },

  /** The vendored Vosk engine version string. */
  engineVersion(): Promise<string> {
    return VoskSpeechModule.engineVersion();
  },

  /** Start mic recognition, optionally restricted to a list of phrases. */
  start(grammar?: string[]): Promise<boolean> {
    return VoskSpeechModule.start(grammar ?? null);
  },

  /** Stop recognition; a final `onResult` is emitted with the remaining text. */
  stop(): void {
    VoskSpeechModule.stop();
  },

  /** Stop and release the recognizer and model. */
  unload(): void {
    VoskSpeechModule.unload();
  },

  onPartialResult(cb: VoskListener): EmitterSubscription {
    return emitter.addListener('onPartialResult', cb);
  },
  onResult(cb: VoskListener): EmitterSubscription {
    return emitter.addListener('onResult', cb);
  },
  onError(cb: VoskListener): EmitterSubscription {
    return emitter.addListener('onError', cb);
  },
};

export default VoskSpeech;
