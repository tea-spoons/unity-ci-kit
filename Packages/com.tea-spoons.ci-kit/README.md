# TeaSpoons CI Kit (Unity package)

Editor-only package with `TeaSpoons.CiKit.BuildRunner`, the headless build entry point used by the
[`build-player`](https://github.com/tea-spoons/unity-ci-kit/tree/main/actions/build-player) GitHub Action.

## Install

Package Manager > **Add package from git URL**:

```
https://github.com/tea-spoons/unity-ci-kit.git?path=/Packages/com.tea-spoons.ci-kit
```

Pin a release by appending a tag, for example `#v0.3.0`.

## Use

```
unity-editor -quit -buildTarget StandaloneLinux64 \
  -executeMethod TeaSpoons.CiKit.BuildRunner.Build \
  -ciBuildTarget StandaloneLinux64 -ciOutputPath ./build
```

| Argument | Meaning |
|---|---|
| `-ciBuildTarget` | `BuildTarget` name (required) |
| `-ciOutputPath` | Output directory (required) |
| `-ciBuildName` | File name without extension (default: product name) |
| `-ciVersion` | `PlayerSettings.bundleVersion` |
| `-ciBuildNumber` | Android versionCode, or iOS / macOS build number |
| `-ciDefines` | Scripting defines to append, `;` separated |
| `-ciScenes` | Scene paths, `;` separated (default: enabled Build Settings scenes) |
| `-ciDevelopment` | `true` for a development build |
| `-ciAndroidAppBundle` | `true` to produce an `.aab` |

Exit codes: `0` success, `10` bad arguments, `11` build failed.

If the project has no scenes in Build Settings, an empty scene is built so library and sample projects still work.
