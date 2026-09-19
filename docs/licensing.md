# Unity licensing in CI

The editor needs a license to run headless. The container actions (`run-tests`, `build-player`, `run-unity`)
accept the license as inputs and activate it inside the container. For `personal` and `serial` they also
return the seat when the run ends, including when tests or the build fail.

Store credentials as **repository secrets** (Settings > Secrets and variables > Actions), never in the workflow file.
GitHub does not pass secrets to workflows triggered from forks, so pull requests from forks will not have a license.

| `license-mode` | For | Secrets |
|---|---|---|
| `personal` | Unity Personal (free), current editors | `UNITY_EMAIL`, `UNITY_PASSWORD` |
| `serial` | Plus / Pro | `UNITY_SERIAL`, `UNITY_EMAIL`, `UNITY_PASSWORD` |
| `ulf` | Older editors that still read a license file | `UNITY_LICENSE` |
| `none` | Editor already licensed (self-hosted) | none |

## Personal (`license-mode: personal`)

Current editors treat a Personal license as an entitlement on your Unity account, so activation is a login with
the account email and password, and the seat is returned afterwards.

```powershell
gh secret set UNITY_EMAIL    --repo <owner>/<repo>
gh secret set UNITY_PASSWORD --repo <owner>/<repo>
```

```yaml
with:
  license-mode: personal
  unity-email: ${{ secrets.UNITY_EMAIL }}
  unity-password: ${{ secrets.UNITY_PASSWORD }}
```

Things to know:

- **Two-factor authentication or SSO on the account can block a headless login.** If activation fails, try a
  dedicated Unity account without them.
- **Activation can exit successfully without granting a seat.** The first Unity run then fails with exit code
  `198` and `No valid Unity Editor license found`. The kit prints a hint when that happens.
- Use a password you are comfortable storing as a secret, and prefer a dedicated account for CI. Check Unity's terms
  for where a Personal license may be used.

## Plus / Pro serial (`license-mode: serial`)

```yaml
with:
  license-mode: serial
  unity-serial: ${{ secrets.UNITY_SERIAL }}
  unity-email: ${{ secrets.UNITY_EMAIL }}
  unity-password: ${{ secrets.UNITY_PASSWORD }}
```

The kit activates with `-serial` at the start of the run and returns the license (`-returnlicense`) when it ends.

## Legacy license file (`license-mode: ulf`)

Older editors read a `Unity_lic.ulf` file. Put its full contents in the `UNITY_LICENSE` secret; the kit writes it
where the editor looks for it.

| OS | Location of the file on a machine with Unity Hub |
|---|---|
| Windows | `C:\ProgramData\Unity\Unity_lic.ulf` |
| macOS | `/Library/Application Support/Unity/Unity_lic.ulf` |
| Linux | `~/.local/share/unity3d/Unity/Unity_lic.ulf` |

```powershell
Get-Content -Raw C:\ProgramData\Unity\Unity_lic.ulf | gh secret set UNITY_LICENSE --repo <owner>/<repo>
```

**This did not work with Unity 6 (6000.0.84f1) in testing:** the editor's licensing client found no entitlements
and exited with code 198. Use `personal` for current editors.

## Unity installed on the runner

Self-hosted runners that already have the editor can skip containers and use the host actions:

```yaml
- uses: tea-spoons/unity-ci-kit/actions/activate-license@v0
  with:
    license-mode: personal
    unity-path: /opt/unity/Editor/Unity
    unity-email: ${{ secrets.UNITY_EMAIL }}
    unity-password: ${{ secrets.UNITY_PASSWORD }}

# ... your steps ...

- uses: tea-spoons/unity-ci-kit/actions/return-license@v0
  if: always()
  with:
    license-mode: personal
    unity-path: /opt/unity/Editor/Unity
    unity-email: ${{ secrets.UNITY_EMAIL }}
    unity-password: ${{ secrets.UNITY_PASSWORD }}
```

## Not covered yet

Floating licenses from a license server are not supported.
