#!/usr/bin/env bash
# Runs one or more Unity command lines inside a unityci/editor container.
#
# Runs on the CI host. Everything is passed through environment variables so
# secrets never appear on a command line:
#
#   UNITY_VERSION      Editor version, e.g. 6000.0.84f1            (required unless UNITY_IMAGE is set)
#   UNITY_COMPONENT    Image component: base, android, ios, webgl,
#                      windows-mono, mac-mono, linux-il2cpp          (default: base)
#   UNITY_IMAGE_VERSION  Image revision suffix                       (default: 3)
#   UNITY_IMAGE        Full image reference, overrides the three above
#   PROJECT_PATH       Unity project, relative to the workspace      (default: .)
#   UNITY_COMMANDS     One Unity argument line per row. Each row is a separate
#                      Unity invocation, run in order.
#   LICENSE_MODE       personal | ulf | serial | none                (default: none)
#   UNITY_EMAIL, UNITY_PASSWORD                             (LICENSE_MODE=personal)
#   UNITY_LICENSE      Contents of the .ulf file          (LICENSE_MODE=ulf, older editors)
#   UNITY_SERIAL, UNITY_EMAIL, UNITY_PASSWORD               (LICENSE_MODE=serial)
#   UNITY_BIN          Editor command inside the image        (default: unity-editor)
#   LICENSING_CLIENT   Unity.Licensing.Client path inside the image (default: under /opt/unity)
#   LICENSE_ACTIVATION_ATTEMPTS / LICENSE_ACTIVATION_RETRY_DELAY   Personal seat retries (default: 3 / 15s)
#   CONTINUE_ON_ERROR  1 = run every row and report the worst exit code
#   WORKSPACE          Directory mounted into the container  (default: $GITHUB_WORKSPACE or $PWD)
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

workspace="${WORKSPACE:-${GITHUB_WORKSPACE:-$PWD}}"
component="${UNITY_COMPONENT:-base}"
image_version="${UNITY_IMAGE_VERSION:-3}"

if [[ -n "${UNITY_IMAGE:-}" ]]; then
  image="$UNITY_IMAGE"
elif [[ -n "${UNITY_VERSION:-}" ]]; then
  image="unityci/editor:ubuntu-${UNITY_VERSION}-${component}-${image_version}"
else
  echo "::error::Set UNITY_VERSION or UNITY_IMAGE." >&2
  exit 64
fi

if [[ -z "${UNITY_COMMANDS:-}" ]]; then
  echo "::error::UNITY_COMMANDS is empty; nothing to run." >&2
  exit 64
fi

echo "Using image: ${image}"

docker run --rm \
  --workdir /github/workspace \
  --volume "${workspace}:/github/workspace" \
  --volume "${script_dir}/container-entry.sh:/kit/container-entry.sh:ro" \
  --env HOST_UID="$(id -u)" \
  --env HOST_GID="$(id -g)" \
  --env PROJECT_PATH="${PROJECT_PATH:-.}" \
  --env LICENSE_MODE="${LICENSE_MODE:-none}" \
  --env CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}" \
  --env UNITY_BIN \
  --env LICENSING_CLIENT \
  --env LICENSE_ACTIVATION_ATTEMPTS \
  --env LICENSE_ACTIVATION_RETRY_DELAY \
  --env UNITY_COMMANDS \
  --env UNITY_LICENSE \
  --env UNITY_SERIAL \
  --env UNITY_EMAIL \
  --env UNITY_PASSWORD \
  "${image}" \
  bash /kit/container-entry.sh
