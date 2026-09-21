# Changelog

## [0.4.0]

- `prepare-test-install.sh` now resolves a package's tea-spoons dependencies **transitively**,
  not just its direct ones. Unity's package resolver hard-fails the whole project if any embedded
  package - including a sibling brought in for the check - declares a dependency that isn't
  present, so a dependency's own dependencies have to be embedded too for the check to run at
  all. This was found via `org-test-install.yml`'s first real run: `stacking-dialogs` failed
  instantly because its dependency `addressables-toolbox` itself depends on `package-core`, which
  wasn't embedded.

## [0.3.2]

- Fix `prepare-test-install.sh`: `TAG_FORMAT` and `REPO_OVERRIDES` (which `actions/test-install`
  always exports, even at their default values) hit a bash pitfall where `${VAR:-word}` silently
  corrupts `word` when it contains a literal `}` and `VAR` is set - every sibling-dependency tag
  lookup was resolving to e.g. `v0.7.2}` instead of `v0.7.2`, always missing on the first try and
  falling back to the sibling's latest tag (with a spurious "pin is stale" warning) even when the
  declared pin was correct. Checks emptiness explicitly now instead of relying on the pitfall-prone
  default syntax.
- Fix `actions/test-install`: the uploaded-artifact name included `package-path` verbatim, which
  broke for a nested package (e.g. `Packages/com.tea-spoons.ci-kit`) since artifact names can't
  contain `/`. Sanitized now.

## [0.3.1]

- Fix `prepare-test-install.sh`: a package with `package-path: .` (the common case) failed
  immediately with `cp: cannot copy a directory ... into itself`, because the throwaway project
  was built as a subdirectory of the package being copied. The package is now staged externally
  first.
- `org-test-install.yml` now uses `license-mode: personal` - `ulf` doesn't work on Unity 6 (see
  the 0.2.0 entry below), so the org-wide run needs the same `UNITY_EMAIL`/`UNITY_PASSWORD`
  secrets as everything else here.

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
