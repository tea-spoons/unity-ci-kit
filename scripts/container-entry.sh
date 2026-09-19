#!/usr/bin/env bash
# Entry point that runs INSIDE the unityci/editor container.
# Activates a license (if requested), runs each Unity command row, returns the
# license and hands file ownership back to the host user.
# See scripts/run-unity.sh for the environment contract.
set -uo pipefail

unity_bin="${UNITY_BIN:-unity-editor}"   # wrapper shipped in unityci/editor images (adds xvfb + -batchmode)
project_path="${PROJECT_PATH:-.}"
license_mode="${LICENSE_MODE:-none}"
serial_active=0

# shellcheck disable=SC2329  # invoked through the EXIT trap below
cleanup() {
  local code=$?
  if [[ "$serial_active" == "1" ]]; then
    echo "::group::Returning Unity license"
    "$unity_bin" -quit -nographics -logFile /dev/stdout -returnlicense \
      -username "${UNITY_EMAIL:-}" -password "${UNITY_PASSWORD:-}" || echo "::warning::Could not return the Unity license."
    echo "::endgroup::"
  fi
  # Files created as root would break later steps and self-hosted workspace cleanup.
  if [[ -n "${HOST_UID:-}" ]]; then
    chown -R "${HOST_UID}:${HOST_GID:-$HOST_UID}" /github/workspace 2>/dev/null || true
  fi
  exit "$code"
}
trap cleanup EXIT

case "$license_mode" in
  none)
    ;;
  ulf)
    if [[ -z "${UNITY_LICENSE:-}" ]]; then
      echo "::error::LICENSE_MODE=ulf but UNITY_LICENSE is empty." >&2
      exit 65
    fi
    license_dir="${HOME}/.local/share/unity3d/Unity"
    mkdir -p "$license_dir"
    printf '%s' "$UNITY_LICENSE" > "${license_dir}/Unity_lic.ulf"
    ;;
  serial)
    for var in UNITY_SERIAL UNITY_EMAIL UNITY_PASSWORD; do
      if [[ -z "${!var:-}" ]]; then
        echo "::error::LICENSE_MODE=serial but ${var} is empty." >&2
        exit 65
      fi
    done
    echo "::group::Activating Unity license"
    "$unity_bin" -quit -nographics -logFile /dev/stdout \
      -serial "$UNITY_SERIAL" -username "$UNITY_EMAIL" -password "$UNITY_PASSWORD"
    activation_code=$?
    echo "::endgroup::"
    if [[ $activation_code -ne 0 ]]; then
      echo "::error::Unity license activation failed (exit ${activation_code})." >&2
      exit "$activation_code"
    fi
    serial_active=1
    ;;
  *)
    echo "::error::Unknown LICENSE_MODE '${license_mode}' (use ulf, serial or none)." >&2
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
    (( code > worst )) && worst=$code
    [[ "${CONTINUE_ON_ERROR:-0}" == "1" ]] || exit "$code"
  fi
done <<< "${UNITY_COMMANDS:-}"

exit "$worst"
