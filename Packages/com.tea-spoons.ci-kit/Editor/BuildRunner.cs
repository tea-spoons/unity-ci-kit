using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace TeaSpoons.CiKit
{
    /// <summary>
    /// Headless player build entry point for CI.
    /// Run with <c>-executeMethod TeaSpoons.CiKit.BuildRunner.Build</c> and the arguments below.
    /// <code>
    /// -ciBuildTarget        BuildTarget name (required), e.g. StandaloneLinux64, Android
    /// -ciOutputPath         Output directory (required)
    /// -ciBuildName          File name without extension (default: product name)
    /// -ciVersion            PlayerSettings.bundleVersion
    /// -ciBuildNumber        Android versionCode / iOS + macOS build number
    /// -ciDefines            Scripting defines to append, separated by ';'
    /// -ciScenes             Scene paths separated by ';' (default: enabled Build Settings scenes)
    /// -ciDevelopment        true for a development build
    /// -ciAndroidAppBundle   true to build an .aab
    /// </code>
    /// </summary>
    public static class BuildRunner
    {
        public const int ExitBadArguments = 10;
        public const int ExitBuildFailed = 11;

        const string TempSceneFolder = "Assets/__CiKitTemp";

        public static void Build()
        {
            int code;
            try
            {
                code = Run(new CiArguments(Environment.GetCommandLineArgs()));
            }
            catch (Exception e)
            {
                Debug.LogError($"[CiKit] Unexpected error: {e}");
                code = ExitBuildFailed;
            }

            EditorApplication.Exit(code);
        }

        static int Run(CiArguments args)
        {
            var targetName = args.Get("BuildTarget");
            var outputPath = args.Get("OutputPath");
            if (string.IsNullOrEmpty(targetName) || string.IsNullOrEmpty(outputPath))
            {
                Debug.LogError("[CiKit] -ciBuildTarget and -ciOutputPath are required.");
                return ExitBadArguments;
            }

            if (!Enum.TryParse(targetName, true, out BuildTarget target))
            {
                Debug.LogError($"[CiKit] Unknown build target '{targetName}'.");
                return ExitBadArguments;
            }

            var group = BuildPipeline.GetBuildTargetGroup(target);
            var namedTarget = NamedBuildTarget.FromBuildTargetGroup(group);

            ApplyVersion(args, target);
            ApplyDefines(args, namedTarget);

            var buildAppBundle = target == BuildTarget.Android && args.GetBool("AndroidAppBundle");
            if (target == BuildTarget.Android)
                EditorUserBuildSettings.buildAppBundle = buildAppBundle;

            Directory.CreateDirectory(outputPath);
            var buildName = SafeFileName(args.Get("BuildName", PlayerSettings.productName));

            var options = new BuildPlayerOptions
            {
                target = target,
                targetGroup = group,
                locationPathName = LocationFor(target, outputPath, buildName, buildAppBundle),
                options = args.GetBool("Development") ? BuildOptions.Development : BuildOptions.None,
            };

            var createdTempScene = false;
            try
            {
                options.scenes = ResolveScenes(args, out createdTempScene);

                Debug.Log($"[CiKit] Building {target} to {options.locationPathName}");
                var report = BuildPipeline.BuildPlayer(options);
                var summary = report.summary;

                Debug.Log($"[CiKit] Result: {summary.result}, {summary.totalErrors} error(s), " +
                          $"{summary.totalWarnings} warning(s), {summary.totalSize / (1024 * 1024)} MB, " +
                          $"{summary.totalTime.TotalSeconds:F1}s");

                return summary.result == BuildResult.Succeeded ? 0 : ExitBuildFailed;
            }
            finally
            {
                if (createdTempScene)
                    AssetDatabase.DeleteAsset(TempSceneFolder);
            }
        }

        static void ApplyVersion(CiArguments args, BuildTarget target)
        {
            var version = args.Get("Version");
            if (!string.IsNullOrEmpty(version))
                PlayerSettings.bundleVersion = version;

            var number = args.Get("BuildNumber");
            if (string.IsNullOrEmpty(number))
                return;

            switch (target)
            {
                case BuildTarget.Android when int.TryParse(number, out var code):
                    PlayerSettings.Android.bundleVersionCode = code;
                    break;
                case BuildTarget.iOS:
                    PlayerSettings.iOS.buildNumber = number;
                    break;
                case BuildTarget.StandaloneOSX:
                    PlayerSettings.macOS.buildNumber = number;
                    break;
            }
        }

        static void ApplyDefines(CiArguments args, NamedBuildTarget namedTarget)
        {
            var extra = args.GetList("Defines");
            if (extra.Length == 0)
                return;

            var current = PlayerSettings.GetScriptingDefineSymbols(namedTarget)
                .Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            PlayerSettings.SetScriptingDefineSymbols(namedTarget, string.Join(";", current.Union(extra)));
        }

        static string[] ResolveScenes(CiArguments args, out bool createdTempScene)
        {
            createdTempScene = false;

            var fromArgs = args.GetList("Scenes");
            if (fromArgs.Length > 0)
                return fromArgs;

            var enabled = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
            if (enabled.Length > 0)
                return enabled;

            // A project without scenes (like a fresh sample or library project) still needs to build.
            Debug.LogWarning("[CiKit] No scenes in Build Settings; building an empty scene.");
            AssetDatabase.CreateFolder("Assets", "__CiKitTemp");
            var path = $"{TempSceneFolder}/Empty.unity";
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene, path);
            createdTempScene = true;
            return new[] { path };
        }

        static string LocationFor(BuildTarget target, string outputPath, string name, bool appBundle)
        {
            switch (target)
            {
                case BuildTarget.StandaloneWindows:
                case BuildTarget.StandaloneWindows64:
                    return Path.Combine(outputPath, name + ".exe");
                case BuildTarget.StandaloneOSX:
                    return Path.Combine(outputPath, name + ".app");
                case BuildTarget.StandaloneLinux64:
                    return Path.Combine(outputPath, name + ".x86_64");
                case BuildTarget.Android:
                    return Path.Combine(outputPath, name + (appBundle ? ".aab" : ".apk"));
                default:
                    // iOS (Xcode project), WebGL and others build into a directory.
                    return outputPath;
            }
        }

        static string SafeFileName(string name)
        {
            var invalid = Path.GetInvalidFileNameChars();
            var cleaned = new string(name.Where(c => !invalid.Contains(c)).ToArray()).Trim();
            return string.IsNullOrEmpty(cleaned) ? "Player" : cleaned;
        }
    }
}
