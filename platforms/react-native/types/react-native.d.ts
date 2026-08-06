// Minimal ambient shim so this package type-checks standalone (without the host
// app's node_modules). The real 'react-native' types come from the peerDependency.
declare module 'react-native' {
  export interface EmitterSubscription { remove(): void; }
  export class NativeEventEmitter {
    constructor(nativeModule?: unknown);
    addListener(event: string, listener: (payload: any) => void): EmitterSubscription;
  }
  export const NativeModules: { [name: string]: any };
}
