# Changelog

## [Unreleased]

- New `license-mode: personal`: activates a Unity Personal license through the Unity account
  (`UNITY_EMAIL` + `UNITY_PASSWORD`) and returns the seat afterwards. The `.ulf` route did not work
  on Unity 6, so `personal` is now the default of the reusable workflows and the sample.
- A run that exits with code 198 (no valid license) now says so.

## [0.1.1]

- Package `author` now lists Muhammad Tarek Abdou.
- Fix CI lint and make the dry-run publish check pass after a release.

## [0.1.0]

- Actions: `run-unity`, `run-tests`, `build-player`, `activate-license`, `return-license`, `validate-package`, `publish-package`.
- Reusable workflows: `test.yml`, `build.yml`, `release-package.yml`.
- Unity package `com.tea-spoons.ci-kit` with the `BuildRunner` entry point.
- Sample project and script tests.
