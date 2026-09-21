# unity-ci-kit

Small, composable GitHub Actions for Unity projects: **run tests, build players, handle Unity licensing and
publish UPM packages.** Use the whole kit or just the piece you need.

Part of the [tea-spoons](https://github.com/tea-spoons) collection of Unity tools.

| Piece | What it does |
|---|---|
| [`actions/run-tests`](actions/run-tests) | EditMode / PlayMode tests in a container, NUnit results as an artifact, summary table on the job page |
| [`actions/build-player`](actions/build-player) | Headless player build for any target, uploads the output |
| [`actions/run-unity`](actions/run-unity) | Escape hatch: run any Unity command line in a container, with licensing handled |
| [`actions/activate-license`](actions/activate-license), [`return-license`](actions/return-license) | Licensing for Unity installed on the runner (self-hosted) |
| [`actions/validate-package`](actions/validate-package) | Checks `package.json`, `.meta` coverage and GUID uniqueness of a UPM package |
| [`actions/test-install`](actions/test-install) | Compiles a package alone, with only the dependencies it declares in `package.json` - catches an undeclared dependency on a sibling package |
| [`actions/publish-package`](actions/publish-package) | Tags a package, creates a GitHub release with a tarball, optionally writes an index page |
| [`Packages/com.tea-spoons.ci-kit`](Packages/com.tea-spoons.ci-kit) | Unity package with the `BuildRunner` that `build-player` calls |

Ready-made reusable workflows wrap these: [`test.yml`](.github/workflows/test.yml),
[`build.yml`](.github/workflows/build.yml), [`test-install.yml`](.github/workflows/test-install.yml)
and [`release-package.yml`](.github/workflows/release-package.yml).

[`org-test-install.yml`](.github/workflows/org-test-install.yml) runs `test-install` against every
package in the org on a weekly schedule (also triggerable by hand), so no individual repo needs to
opt in for the check to run - see [docs/test-install.md](docs/test-install.md).

## Quick start

Test on every push, using a Unity Personal license (see [docs/licensing.md](docs/licensing.md) for the secrets):

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    uses: tea-spoons/unity-ci-kit/.github/workflows/test.yml@v0
    with:
      unity-version: 6000.0.84f1
      test-mode: all
    secrets: inherit
```

Build several targets:

```yaml
  build:
    needs: test
    uses: tea-spoons/unity-ci-kit/.github/workflows/build.yml@v0
    with:
      unity-version: 6000.0.84f1
      build-targets: '["StandaloneLinux64", "StandaloneWindows64", "WebGL"]'
    secrets: inherit
```

`build-player` calls `TeaSpoons.CiKit.BuildRunner.Build`, so add the package to your project
(Package Manager > **Add package from git URL**):

```
https://github.com/tea-spoons/unity-ci-kit.git?path=/Packages/com.tea-spoons.ci-kit#v0.3.2
```

Prefer your own build script? Pass `execute-method: MyCompany.Build.Run` and skip the package.

### Just one action

Every action stands alone; inputs beyond the required ones are optional.

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: tea-spoons/unity-ci-kit/actions/run-tests@v0
    with:
      unity-version: 6000.0.84f1
      project-path: MyGame
      license-mode: ulf
      unity-license: ${{ secrets.UNITY_LICENSE }}
```

Publish a package you keep in a repo (tags `v<version>` and attaches a tarball):

```yaml
permissions:
  contents: write
steps:
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0
  - uses: tea-spoons/unity-ci-kit/actions/publish-package@v0
    with:
      package-path: Packages/com.example.mypackage
```

For a repo with several packages use `tag-format: "{name}-v{version}"`.

## How it works

Actions run Unity in the public [`unityci/editor`](https://hub.docker.com/r/unityci/editor) images
(`unityci/editor:ubuntu-<version>-<component>-<image-version>`), so you need a Linux runner with Docker
(`ubuntu-latest` works). The component is picked from the build target: `android`, `ios`, `webgl`, `windows-mono`,
`mac-mono`, otherwise `base`. Override it with `component`, or pass a whole `unity-image`.

- iOS builds produce an Xcode project only. Compiling it needs a macOS runner with Xcode.
- The Unity `Library` folder can be cached between runs; the reusable workflows do this for you.
- Secrets reach the container as environment variables, never on a command line.

## Try it

`examples/sample-project` is a tiny Unity project with EditMode and PlayMode tests.
The [`sample`](.github/workflows/sample.yml) workflow runs the kit against it. Add your Unity secrets to the
repository and start it from the Actions tab.

## Development

```bash
bash tests/validate-package.test.sh   # package validator
bash tests/run-unity.test.sh          # container runner, uses a fake editor (needs Docker)
```

CI also runs `shellcheck` and `actionlint`.

## License

[MIT](LICENSE). Unity is a trademark of Unity Technologies; this project is not affiliated with or endorsed by
Unity. Your Unity license terms apply to running the editor in CI.
