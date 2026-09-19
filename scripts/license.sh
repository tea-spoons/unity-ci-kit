#!/usr/bin/env bash
# Activates or returns a Unity license on the host (no container).
#
# Usage: license.sh <activate|return>
#
#   LICENSE_MODE     ulf | serial
#   UNITY_PATH       Editor executable (default: unity-editor)
#   UNITY_LICENSE    .ulf contents            (activate, ulf)
#   UNITY_SERIAL     serial key               (activate, serial)
#   UNITY_EMAIL, UNITY_PASSWORD               (serial)
set -euo pipefail

action="${1:?usage: license.sh <activate|return>}"
mode="${LICENSE_MODE:?LICENSE_MODE is required (ulf or serial)}"
unity="${UNITY_PATH:-unity-editor}"

require() {
  local var
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      echo "::error::${var} is required for license-mode=${mode}." >&2
      exit 65
    fi
  done
}

# Where Unity looks for a Personal license file on each OS.
ulf_dir() {
  case "${RUNNER_OS:-$(uname -s)}" in
    Linux)          echo "${HOME}/.local/share/unity3d/Unity" ;;
    macOS|Darwin)   echo "/Library/Application Support/Unity" ;;
    Windows|MINGW*|MSYS*) echo "${PROGRAMDATA:-C:/ProgramData}/Unity" ;;
    *) echo "::error::Unsupported OS for license file placement." >&2; exit 64 ;;
  esac
}

# macOS writes into /Library, which needs elevation on hosted runners.
maybe_sudo() {
  if [[ "${RUNNER_OS:-}" == "macOS" ]]; then sudo "$@"; else "$@"; fi
}

case "${action}:${mode}" in
  activate:ulf)
    require UNITY_LICENSE
    dir="$(ulf_dir)"
    maybe_sudo mkdir -p "$dir"
    printf '%s' "$UNITY_LICENSE" | maybe_sudo tee "${dir}/Unity_lic.ulf" > /dev/null
    echo "License file written."
    ;;
  activate:serial)
    require UNITY_SERIAL UNITY_EMAIL UNITY_PASSWORD
    "$unity" -quit -batchmode -nographics -logFile - \
      -serial "$UNITY_SERIAL" -username "$UNITY_EMAIL" -password "$UNITY_PASSWORD"
    ;;
  return:ulf)
    maybe_sudo rm -f "$(ulf_dir)/Unity_lic.ulf"
    echo "License file removed."
    ;;
  return:serial)
    require UNITY_EMAIL UNITY_PASSWORD
    "$unity" -quit -batchmode -nographics -logFile - \
      -returnlicense -username "$UNITY_EMAIL" -password "$UNITY_PASSWORD"
    ;;
  *)
    echo "::error::Unsupported combination '${action}' / '${mode}'." >&2
    exit 64
    ;;
esac
