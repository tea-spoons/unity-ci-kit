#!/usr/bin/env bash
# Tags the current commit and publishes a GitHub release with a UPM-style tarball.
#
# Usage: publish-package.sh <package-dir>
#
#   TAG_FORMAT      Tag template, {name} and {version} are replaced (default: v{version})
#   GH_TOKEN        Token with contents:write (required unless DRY_RUN=1)
#   DRY_RUN         1 = validate and report what would happen, publish nothing
#   GITHUB_OUTPUT   When set, receives tag / install-url / tarball outputs
# Needs: git, jq, gh (unless DRY_RUN=1).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg="${1:?usage: publish-package.sh <package-dir>}"
pkg="${pkg%/}"; pkg="${pkg#./}"; pkg="${pkg:-.}"

bash "${script_dir}/validate-package.sh" "$pkg"

name="$(jq -r .name "$pkg/package.json")"
version="$(jq -r .version "$pkg/package.json")"

default_format='v{version}'
tag="${TAG_FORMAT:-$default_format}"
tag="${tag//\{name\}/$name}"
tag="${tag//\{version\}/$version}"

if git ls-remote --exit-code --tags origin "refs/tags/${tag}" > /dev/null 2>&1; then
  echo "::error::Tag ${tag} already exists. Bump the version in ${pkg}/package.json first." >&2
  exit 1
fi

repo_url="https://github.com/${GITHUB_REPOSITORY:-owner/repo}"
install="${repo_url}.git"
[[ "$pkg" != "." ]] && install+="?path=/${pkg}"
install+="#${tag}"

tarball="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/${name}-${version}.tgz"
# UPM tarballs keep everything under a top-level "package/" folder.
if [[ "$pkg" == "." ]]; then
  git archive --format=tar.gz --prefix=package/ -o "$tarball" HEAD
else
  git archive --format=tar.gz --prefix=package/ -o "$tarball" "HEAD:${pkg}"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "tag=${tag}"
    echo "install-url=${install}"
    echo "tarball=${tarball}"
  } >> "$GITHUB_OUTPUT"
fi

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "[dry run] Would publish ${name}@${version} as tag ${tag}"
  echo "[dry run] Tarball: ${tarball}"
  echo "[dry run] Install URL: ${install}"
  exit 0
fi

gh release create "$tag" "$tarball" \
  --target "${GITHUB_SHA:-$(git rev-parse HEAD)}" \
  --title "${name} ${version}" \
  --generate-notes

echo "Published ${name}@${version} as ${tag}"
echo "Install URL: ${install}"
