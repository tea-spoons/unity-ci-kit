# Unity licensing in CI

The editor needs a license to run headless. The container actions (`run-tests`, `build-player`, `run-unity`)
accept the license as inputs and activate it inside the container; for a serial license they also return it afterwards.

Store credentials as **repository secrets** (Settings > Secrets and variables > Actions), never in the workflow file.
GitHub does not pass secrets to workflows triggered from forks, so pull requests from forks will not have a license.

## Personal license (`license-mode: ulf`)

| Secret | Value |
|---|---|
| `UNITY_LICENSE` | Full contents of your `Unity_lic.ulf` file |

The `.ulf` file is created when a Personal license is activated on a machine with Unity Hub:

| OS | Location |
|---|---|
| Windows | `C:\ProgramData\Unity\Unity_lic.ulf` |
| macOS | `/Library/Application Support/Unity/Unity_lic.ulf` |
| Linux | `~/.local/share/unity3d/Unity/Unity_lic.ulf` |

A license showing in Unity Hub does not always mean the file exists; make sure the activation was fully completed
on that machine. Licenses are tied to your account and Unity's rules about where they can be used, so check Unity's terms.

```yaml
with:
  license-mode: ulf
  unity-license: ${{ secrets.UNITY_LICENSE }}
```

## Plus / Pro serial (`license-mode: serial`)

| Secret | Value |
|---|---|
| `UNITY_SERIAL` | Your serial key |
| `UNITY_EMAIL` | Unity account email |
| `UNITY_PASSWORD` | Unity account password |

The kit activates with `-serial` at the start of the run and returns the license (`-returnlicense`) when it ends,
including when tests or the build fail, so seats are not left in use.

```yaml
with:
  license-mode: serial
  unity-serial: ${{ secrets.UNITY_SERIAL }}
  unity-email: ${{ secrets.UNITY_EMAIL }}
  unity-password: ${{ secrets.UNITY_PASSWORD }}
```

## Unity installed on the runner

Self-hosted runners that already have the editor can skip containers and use the host actions:

```yaml
- uses: tea-spoons/unity-ci-kit/actions/activate-license@v0
  with:
    license-mode: serial
    unity-path: /opt/unity/Editor/Unity
    unity-serial: ${{ secrets.UNITY_SERIAL }}
    unity-email: ${{ secrets.UNITY_EMAIL }}
    unity-password: ${{ secrets.UNITY_PASSWORD }}

# ... your steps ...

- uses: tea-spoons/unity-ci-kit/actions/return-license@v0
  if: always()
  with:
    license-mode: serial
    unity-path: /opt/unity/Editor/Unity
    unity-email: ${{ secrets.UNITY_EMAIL }}
    unity-password: ${{ secrets.UNITY_PASSWORD }}
```

## Not covered yet

Floating licenses from a license server are not supported in v1.
