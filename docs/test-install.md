# Test-installing a package in isolation

A package's `Packages/manifest.json` `dependencies` field is what a *consumer* installs. A dev
project that keeps every package of the org embedded together (a "playground") will happily
compile even when a package's C# quietly references a type from a sibling it never declared -
the sibling is just sitting right there. Anyone who installs that package on its own hits a
compile error the playground never showed.

`actions/test-install` catches this: it builds a throwaway project containing only the package
under test, plus exactly the dependencies listed in its own `package.json` (each fetched from
its GitHub repo at the tag that version should have been published as), and compiles it.

## What it does and doesn't catch

- **Catches:** a package using a type/namespace from a `com.tea-spoons.*` package it doesn't
  declare as a dependency.
- **Doesn't catch:** a *declared* dependency's own undeclared dependencies - each package is
  checked with its declared dependency embedded as-is, one level deep, not recursively. That
  package gets caught by its own `test-install` run instead.
- **Also surfaces, as a warning (not a failure):** a declared dependency version that was never
  published as a tag. The check falls back to that sibling's latest tag so it can still run, but
  the warning means the pin in `package.json` is stale and should be bumped.

## Using it

On one package, in its own repo's workflow:

```yaml
jobs:
  test-install:
    uses: tea-spoons/unity-ci-kit/.github/workflows/test-install.yml@v0
    with:
      unity-version: 6000.0.84f1
    secrets: inherit
```

Or as a single step alongside other actions:

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: tea-spoons/unity-ci-kit/actions/test-install@v0
    with:
      package-path: .
      unity-version: 6000.0.84f1
      license-mode: personal
      unity-email: ${{ secrets.UNITY_EMAIL }}
      unity-password: ${{ secrets.UNITY_PASSWORD }}
```

For a repo where the package isn't at the repo root (like this one - see
`Packages/com.tea-spoons.ci-kit`), set `package-path` to that subfolder.

## Org-wide, on a schedule

No repo has to opt in for this to run: [`org-test-install.yml`](../.github/workflows/org-test-install.yml)
lives here in unity-ci-kit, discovers every UPM package across the `tea-spoons` org
(`scripts/discover-packages.sh`), and runs `test-install` against each of them weekly. Trigger it
by hand from the Actions tab (`workflow_dispatch`) to check sooner. It needs the same
`UNITY_EMAIL` / `UNITY_PASSWORD` repository secrets as the other license-mode `personal` actions
(see [licensing.md](licensing.md)).

New packages need nothing added here - they're picked up by the next scheduled (or manual) run.
A renamed repo whose package name doesn't match it, like `unity-ci-kit` -> `com.tea-spoons.ci-kit`,
needs an entry in `actions/test-install`'s `repo-overrides` input (or `REPO_OVERRIDES` env var for
the script directly).
