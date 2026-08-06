// VoskModelDiscovery.cs — model discovery + version info for Unity, backed by the
// same Swift locator (via the FFI) so selection rules stay in one place.
//
// Drop a new model (e.g. atc-lgraph-v11) into your models folder and
// VoskModels.Latest(root) picks the highest version automatically — no code change.

using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace VoskSpeechKit
{
    [Serializable]
    public struct VoskModelInfo
    {
        public string path;
        public string name;               // e.g. "atc-lgraph"
        public string version;            // e.g. "11"
        public string voskEngineVersion;  // engine the model targets / vendored engine
        public double sampleRate;
        public string source;             // "manifest" | "folderName"
        public string displayName;        // e.g. "atc-lgraph v11 · Vosk 0.3…"
    }

    [Serializable]
    internal struct VoskModelInfoList { public VoskModelInfo[] items; }

    /// <summary>Discovers Vosk models under a folder and picks one by version.</summary>
    public static class VoskModels
    {
        /// <summary>Highest-version model under <paramref name="modelsRoot"/>, or null.</summary>
        public static VoskModelInfo? Latest(string modelsRoot)
        {
            string json = Discovery.Consume(Discovery.vsk_latest_model_json(modelsRoot));
            if (string.IsNullOrEmpty(json)) return null;
            return JsonUtility.FromJson<VoskModelInfo>(json);
        }

        /// <summary>Every model discovered under <paramref name="modelsRoot"/>.</summary>
        public static VoskModelInfo[] Available(string modelsRoot)
        {
            string json = Discovery.Consume(Discovery.vsk_available_models_json(modelsRoot));
            if (string.IsNullOrEmpty(json)) return Array.Empty<VoskModelInfo>();
            // JsonUtility can't parse a top-level array — wrap it.
            return JsonUtility.FromJson<VoskModelInfoList>("{\"items\":" + json + "}").items;
        }
    }

    public static class VoskEngine
    {
        /// <summary>The vendored Vosk engine version string.</summary>
        public static string Version() => Discovery.Consume(Discovery.vsk_engine_version());
    }

    internal static class Discovery
    {
#if UNITY_IOS && !UNITY_EDITOR
        private const string LIB = "__Internal";
#else
        private const string LIB = "VoskSpeechFFI";
#endif
        [DllImport(LIB)] internal static extern IntPtr vsk_engine_version();
        [DllImport(LIB)] internal static extern IntPtr vsk_latest_model_json([MarshalAs(UnmanagedType.LPStr)] string root);
        [DllImport(LIB)] internal static extern IntPtr vsk_available_models_json([MarshalAs(UnmanagedType.LPStr)] string root);
        [DllImport(LIB)] internal static extern void vsk_string_free(IntPtr ptr);

        internal static string Consume(IntPtr ptr)
        {
            if (ptr == IntPtr.Zero) return "";
            string s = Marshal.PtrToStringAnsi(ptr) ?? "";
            vsk_string_free(ptr);
            return s;
        }
    }
}
