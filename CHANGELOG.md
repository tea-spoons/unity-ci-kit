# Changelog

## [0.3.0]

- New `actions/test-install` (+ reusable `test-install.yml`): compiles a package alone, with only
  the dependencies it declares in its own `package.json`, to catch an undeclared dependency on a
  sibling package. Falls back (with a warning) to a sibling's latest tag when a declared version
  was never published.
- New `org-test-install.yml`: runs `test-install` weekly across every UPM package in the org,
  discovered automatically (`scripts/discover-packages.sh`) - no per-repo opt-in needed.

## [0.2.0]

**Behavior change:** the reusable workflows (`test.yml`, `build.yml`) and the sample now default to `license-mode: personal`
(was `ulf`). Pass `license-mode: ulf` to keep the old behavior on older editors.

- New `license-mode: personal`: activates a Unity Personal license through the Unity account
  (`UNITY_EMAIL` + `UNITY_PASSWORD`) and returns the seat afterwards. Containers use the editor's
  licensing client (`--activate-all --include-personal`, `--return-ulf`), with a login through the editor
  as fallback for older editors; success means a seat was assigned, with up to 3 attempts.
  The `.ulf` route did not work on Unity 6, so `personal` is now the default of the reusable workflows and the sample.
- Entitlement-based Personal seats (no ULF file) are returned through the editor when `--return-ulf` finds nothing to return.
- `activate-license` / `return-license` take an optional `licensing-client` input for Personal on current editors.
- A run that exits with code 198 (no valid license) now says so.

## [0.1.1]

- Package `author` now lists Muhammad Tarek Abdou.
- Fix CI lint and make the dry-run publish check pass after a release.

## [0.1.0]

- Actions: `run-unity`, `run-tests`, `build-player`, `activate-license`, `return-license`, `validate-package`, `publish-package`.
- Reusable workflows: `test.yml`, `build.yml`, `release-package.yml`.
- Unity package `com.tea-spoons.ci-kit` with the `BuildRunner` entry point.
- Sample project and script tests.
