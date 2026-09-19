#!/usr/bin/env bash
# Entry point that runs INSIDE the unityci/editor container.
# Activates a license (if requested), runs each Unity command row, returns the
# license and hands file ownership back to the host user.
# See scripts/run-unity.sh for the environment contract.
set -uo pipefail

unity_bin="${UNITY_BIN:-unity-editor}"   # wrapper shipped in unityci/editor images (adds xvfb + -batchmode)
unity_path="${UNITY_PATH:-/opt/unity}"
licensing_client="${LICENSING_CLIENT:-${unity_path}/Editor/Data/Resources/Licensing/Client/Unity.Licensing.Client}"
project_path="${PROJECT_PATH:-.}"
license_mode="${LICENSE_MODE:-none}"
activation_attempts="${LICENSE_ACTIVATION_ATTEMPTS:-3}"
activation_retry_delay="${LICENSE_ACTIVATION_RETRY_DELAY:-15}"

# How a taken seat has to be given back: client (licensing client), editor (-returnlicense) or none.
return_route=none

# shellcheck disable=SC2317,SC2329  # invoked through the EXIT trap below
cleanup() {
  local code=$?
  case "$return_route" in
    client)
      echo "::group::Returning Unity license"
      if ! "$licensing_client" --return-ulf; then
        # Personal seats on current editors are account entitlements, not a ULF file, so there is
        # nothing for --return-ulf to return. Give the seat back through the editor instead.
        echo "Returning the seat through the editor instead."
        "$unity_bin" -quit -nographics -logFile /dev/stdout -returnlicense \
          -username "${UNITY_EMAIL:-}" -password "${UNITY_PASSWORD:-}" || echo "::warning::Could not return the Unity license."
      fi
      echo "::endgroup::"
      ;;
    editor)
      echo "::group::Returning Unity license"
      "$unity_bin" -quit -nographics -logFile /dev/stdout -returnlicense \
        -username "${UNITY_EMAIL:-}" -password "${UNITY_PASSWORD:-}" || echo "::warning::Could not return the Unity license."
      echo "::endgroup::"
      ;;
  esac
  # Files created as root would break later steps and self-hosted workspace cleanup.
  if [[ -n "${HOST_UID:-}" ]]; then
    chown -R "${HOST_UID}:${HOST_GID:-$HOST_UID}" /github/workspace 2>/dev/null || true
  fi
  exit "$code"
}
trap cleanup EXIT

require_env() {
  local var
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      echo "::error::LICENSE_MODE=${license_mode} but ${var} is empty." >&2
      exit 65
    fi
  done
}

# Runs one Personal activation attempt and reports whether Unity granted a seat.
# Unity's client exits 0 when it merely processed the request, so success is judged from its output.
personal_attempt() {
  local output code
  if [[ "$personal_route" == "client" ]]; then
    output="$("$licensing_client" --activate-all --include-personal \
      --username "$UNITY_EMAIL" --password "$UNITY_PASSWORD" 2>&1)"
    code=$?
    printf '%s\n' "$output"
    [[ $code -eq 0 ]] || return 1
    ! grep -q -i -E 'No seat available|assigned no seat' <<< "$output"
  else
    output="$("$unity_bin" -quit -nographics -logFile /dev/stdout \
      -username "$UNITY_EMAIL" -password "$UNITY_PASSWORD" 2>&1)"
    printf '%s\n' "$output"
    # "Successfully resolved entitlements" only means the query worked; a grant is reported like this:
    grep -q 'Serial number assigned to' <<< "$output"
  fi
}

case "$license_mode" in
  none)
    ;;
  personal)
    # Current editors treat a Personal license as an entitlement on the Unity account.
    # Newer licensing clients can request the seat themselves; older editors have to do it through the editor.
    require_env UNITY_EMAIL UNITY_PASSWORD
    personal_route=editor
    if [[ -x "$licensing_client" ]]; then
      client_help="$("$licensing_client" --help 2>&1)"   # captured first: grep -q + pipefail can misreport
      if grep -q -- '--include-personal' <<< "$client_help"; then
        personal_route=client
      fi
    fi
    echo "::group::Activating Unity Personal license (via ${personal_route})"
    granted=0
    for (( attempt = 1; attempt <= activation_attempts; attempt++ )); do
      if personal_attempt; then granted=1; break; fi
      if (( attempt < activation_attempts )); then
        echo "No seat granted (attempt ${attempt}/${activation_attempts}); retrying in ${activation_retry_delay}s."
        sleep "$activation_retry_delay"
      fi
    done
    echo "::endgroup::"
    if [[ $granted -ne 1 ]]; then
      echo "::error::Unity did not grant a Personal seat after ${activation_attempts} attempt(s). This is decided by Unity's servers and can clear on a re-run; a Plus/Pro serial (license-mode: serial) avoids it." >&2
      exit 66
    fi
    return_route="$personal_route"
    if [[ "$personal_route" == "client" ]]; then
      # Informational: lists what this account may use, which helps when a run still reports no license.
      "$licensing_client" --showEntitlements 2>&1 | head -n 40 || true
    fi
    ;;
  ulf)
    require_env UNITY_LICENSE
    license_dir="${HOME}/.local/share/unity3d/Unity"
    mkdir -p "$license_dir"
    printf '%s' "$UNITY_LICENSE" > "${license_dir}/Unity_lic.ulf"
    ;;
  serial)
    require_env UNITY_SERIAL UNITY_EMAIL UNITY_PASSWORD
    echo "::group::Activating Unity license"
    "$unity_bin" -quit -nographics -logFile /dev/stdout \
      -serial "$UNITY_SERIAL" -username "$UNITY_EMAIL" -password "$UNITY_PASSWORD"
    activation_code=$?
    echo "::endgroup::"
    if [[ $activation_code -ne 0 ]]; then
      echo "::error::Unity license activation failed (exit ${activation_code})." >&2
      exit "$activation_code"
    fi
    return_route=editor
    ;;
  *)
    echo "::error::Unknown LICENSE_MODE '${license_mode}' (use personal, ulf, serial or none)." >&2
    exit 64
    ;;
esac

worst=0
while IFS= read -r row; do
  [[ -z "${row//[[:space:]]/}" ]] && continue

  # xargs understands quotes, so an argument like -coverageOptions "a;b" stays intact
  # without resorting to eval.
  mapfile -d '' -t args < <(printf '%s' "$row" | xargs printf '%s\0')

  echo "::group::unity ${args[*]}"
  "$unity_bin" -projectPath "$project_path" -logFile /dev/stdout "${args[@]}"
  code=$?
  echo "::endgroup::"

  if [[ $code -ne 0 ]]; then
    echo "Unity exited with code ${code}"
    if [[ $code -eq 198 ]]; then
      echo "::error::Unity found no valid license (exit 198). Check license-mode and the secrets; see docs/licensing.md."
    fi
    (( code > worst )) && worst=$code
    [[ "${CONTINUE_ON_ERROR:-0}" == "1" ]] || exit "$code"
  fi
done <<< "${UNITY_COMMANDS:-}"

exit "$worst"
