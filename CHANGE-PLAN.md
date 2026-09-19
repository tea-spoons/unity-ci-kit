# Change plan

> Draft. This file tracks what I plan to change next. Edit freely.

## Origin

Written from scratch by me (Muhammad Tarek Abdou) in 2026 and released under the MIT license. It is not derived from any
employer's code.

## Planned changes

- [x] Reusable workflows `test.yml`, `build.yml` and `release-package.yml`, and the actions they use (0.1.0).
- [x] Personal license mode (`license-mode: personal`) with retries and seat return (0.2.0).
<!-- review-items:start -->
- [ ] **P1** Add package mode: an action (and a `test-package.yml` reusable workflow) that creates a throwaway project in the runner's temp folder, with a `Packages/manifest.json` that references the package by `file:` path and lists it (and its own-package dependencies) under `testables`, then runs the existing test logic. This is the setup used to verify the new packages by hand in eight scratch projects. It unblocks the "run tests in CI" item of every package.
- [ ] **P1** Add a `max-parallel` input to `build.yml` (and document it in `docs/licensing.md`), so Personal-license builds can run one target at a time.
- [ ] **P1** Make `validate-package` check `Samples~`: warn when a sample contains YAML assets (prefabs, scenes, materials) without `.meta` files.
- [ ] **P1** Move `v0` automatically: a workflow that, after a release, moves the major tag to the new commit, so `@v0` users do not depend on someone remembering.
- [ ] **P2** Add a Unity version matrix to `test.yml` (an input like `build-targets`, one job per version), and an `auto` version read from `ProjectVersion.txt`.
- [ ] **P2** Add code coverage output (through Unity's Code Coverage package) and publish the summary next to the test table.
- [ ] **P2** Create a check run with per-test annotations for failures when a token is given (GameCI does this).
- [ ] **P2** Add the Standalone test mode.
- [ ] **P2** Check more in `validate-package`: that a `unity` field is set, that the asmdef references resolve, and that `CHANGELOG.md` has an entry for the current version.
- [ ] **P2** Add a `docs/how-it-works.md`: a line-by-line explanation of the kit for people who know GitLab CI (a draft exists).
<!-- review-items:end -->

<!-- review:start -->
## Review (September 2026)

Reviewed as a senior Unity engineer would: I read the code and compared the package with similar open-source projects (September 2026). Those projects are listed for ideas only. Nothing was copied from them, and their licenses are noted in case code is ever reused. Priorities: **P0** correctness bug or broken metadata, **P1** should be done soon, **P2** nice to have.

### Compared with

| Project | License | Worth noting |
|---|---|---|
| [game-ci/unity-test-runner](https://game.ci/docs/github/test-runner/) | MIT | Test modes All, PlayMode, EditMode and Standalone. `packageMode` tests a Unity package instead of a project (Linux only, explicit Unity version, `jq` in custom images). Code coverage (`coverageEnabled`, `coverageOptions`, assembly filters, a `coveragePath` output). With a `githubToken` it creates a check run with the results. `customImage`, `Library` caching for projects, and `auto` as the Unity version for projects. |
| [Unity manual: package layout](https://docs.unity3d.com/Manual/cus-layout.html) | Unity documentation | README, CHANGELOG, LICENSE and Third Party Notices next to `package.json`; `Editor`, `Runtime`, `Tests`, `Samples` and `Documentation` folders (Unity adds the `~` to the last two on export). |

### Findings from reading the code

- **[Gap]** `run-tests` needs a Unity project. Every package repo in the organization is a package with no project, so none of them runs its tests in CI (more than a dozen plans carry the same "run tests in CI" item). GameCI has `packageMode` for this.
- **[Gap]** No code coverage, no check-run annotations for failing tests, and no Standalone test mode.
- **[Gap]** The Unity version must be given. GameCI accepts `auto` for projects (it reads `ProjectSettings/ProjectVersion.txt`).
- **[Seat]** `build.yml` runs its matrix in parallel and does not expose `max-parallel`. With a Personal license only one seat exists, so parallel targets compete for it and can fail to get one (see `docs/licensing.md`).
- **[Validator]** `validate-package.sh` skips every folder that ends with `~`. Assets inside `Samples~` still reference each other by GUID, and a sample imported without its `.meta` files gets new GUIDs and breaks. This was found the hard way in `stacking-dialogs`, `ugui-design-system` and `ui-toolbox`.
- **[Release]** The floating `v0` tag is moved by hand; nothing in the repository does it, and `sample-reusable.yml` only tests whatever `v0` points at.
- **[Platform]** Everything runs in Linux containers. iOS builds produce an Xcode project that needs a macOS runner to compile.
- **[Strength]** Personal licensing by account login with retries and seat return, script tests with a fake editor, and small composable actions.
<!-- review:end -->

## Notes and ideas

_Add your own here._
