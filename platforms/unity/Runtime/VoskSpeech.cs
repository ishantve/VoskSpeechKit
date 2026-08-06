// VoskSpeech.cs — Unity/C# binding over the VoskSpeechFFI C ABI.
// Unity owns audio capture; feed 16 kHz mono Int16 PCM into AcceptWaveform and
// read Result()/PartialResult(). The acoustic model is host-provided (a path in
// the app sandbox / StreamingAssets).

using System;
using System.Runtime.InteropServices;

namespace VoskSpeechKit
{
    /// <summary>A loaded Vosk acoustic model. Load once, share across recognizers.</summary>
    public sealed class VoskModel : IDisposable
    {
        internal IntPtr Handle;

        public VoskModel(string modelPath)
        {
            Handle = NativeMethods.vsk_model_new(modelPath);
            if (Handle == IntPtr.Zero)
                throw new Exception($"Vosk model failed to load at {modelPath}");
        }

        public void Dispose()
        {
            if (Handle == IntPtr.Zero) return;
            NativeMethods.vsk_model_free(Handle);
            Handle = IntPtr.Zero;
        }
    }

    /// <summary>A single recognition stream. Not thread-safe.</summary>
    public sealed class VoskRecognizer : IDisposable
    {
        private IntPtr _handle;

        public VoskRecognizer(VoskModel model, float sampleRate = 16000f)
        {
            _handle = NativeMethods.vsk_recognizer_new(model.Handle, sampleRate);
            if (_handle == IntPtr.Zero)
                throw new Exception("Vosk recognizer failed to initialise");
        }

        /// <summary>Feed 16-bit mono samples. True at an utterance boundary.</summary>
        public bool AcceptWaveform(short[] samples)
            => NativeMethods.vsk_accept_waveform(_handle, samples, samples.Length) == 1;

        public string Result()        => Consume(NativeMethods.vsk_result(_handle));
        public string PartialResult() => Consume(NativeMethods.vsk_partial_result(_handle));
        public string FinalResult()   => Consume(NativeMethods.vsk_final_result(_handle));
        public void   Reset()         => NativeMethods.vsk_reset(_handle);

        public void Dispose()
        {
            if (_handle == IntPtr.Zero) return;
            NativeMethods.vsk_recognizer_free(_handle);
            _handle = IntPtr.Zero;
        }

        private static string Consume(IntPtr ptr)
        {
            if (ptr == IntPtr.Zero) return "";
            string s = Marshal.PtrToStringAnsi(ptr) ?? "";
            NativeMethods.vsk_string_free(ptr);
            return s;
        }
    }

    public static class Vosk
    {
        /// <summary>Global log verbosity (-1 silences).</summary>
        public static void SetLogLevel(int level) => NativeMethods.vsk_set_log_level(level);
    }

    internal static class NativeMethods
    {
#if UNITY_IOS && !UNITY_EDITOR
        private const string LIB = "__Internal";
#else
        private const string LIB = "VoskSpeechFFI";
#endif
        [DllImport(LIB)] internal static extern IntPtr vsk_model_new([MarshalAs(UnmanagedType.LPStr)] string path);
        [DllImport(LIB)] internal static extern void   vsk_model_free(IntPtr model);
        [DllImport(LIB)] internal static extern IntPtr vsk_recognizer_new(IntPtr model, float sampleRate);
        [DllImport(LIB)] internal static extern void   vsk_recognizer_free(IntPtr recognizer);
        [DllImport(LIB)] internal static extern int    vsk_accept_waveform(IntPtr recognizer, short[] data, int length);
        [DllImport(LIB)] internal static extern IntPtr vsk_result(IntPtr recognizer);
        [DllImport(LIB)] internal static extern IntPtr vsk_partial_result(IntPtr recognizer);
        [DllImport(LIB)] internal static extern IntPtr vsk_final_result(IntPtr recognizer);
        [DllImport(LIB)] internal static extern void   vsk_reset(IntPtr recognizer);
        [DllImport(LIB)] internal static extern void   vsk_set_log_level(int level);
        [DllImport(LIB)] internal static extern void   vsk_string_free(IntPtr ptr);
    }
}
