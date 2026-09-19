# Sample project

A minimal Unity project used to exercise the kit's actions (see `.github/workflows/sample.yml`).
It references the kit's package from the repository (`file:../../../Packages/com.tea-spoons.ci-kit`), so the
`BuildRunner` and its tests run against real Unity on every workflow run.

- `Assets/Sample/Runtime`: a tiny `Calculator` class
- `Assets/Sample/Tests/EditMode` and `PlayMode`: tests for it

Open it in Unity Hub with editor 6000.0.84f1 (or change `ProjectSettings/ProjectVersion.txt` and the workflow input).
