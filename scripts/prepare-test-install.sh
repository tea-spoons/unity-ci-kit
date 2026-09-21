#!/usr/bin/env bash
# Builds a throwaway Unity project that embeds ONE package plus exactly the dependencies
# declared in its own package.json - nothing else. Compiling this project is proof the
# package doesn't secretly rely on a sibling package that a real consumer, installing it
# alone, would not have.
#
# Usage: prepare-test-install.sh <package-dir> <project-dir>
#
#   ORG             GitHub org/user the sibling packages live in (default: tea-spoons)
#   TAG_FORMAT      Tag template used when publishing, {name}/{version} replaced (default: v{version})
#   REPO_OVERRIDES  JSON object mapping package name -> repo name, for repos where the package
#                   isn't at the repo root (default: {"com.tea-spoons.ci-kit":"unity-ci-kit"})
#   TEST_FRAMEWORK_VERSION  com.unity.test-framework version for the throwaway project (default: 1.4.6)
# Needs: git, jq.
set -euo pipefail

pkg="${1:?usage: prepare-test-install.sh <package-dir> <project-dir>}"
project="${2:?usage: prepare-test-install.sh <package-dir> <project-dir>}"
pkg="${pkg%/}"; pkg="${pkg:-.}"

org="${ORG:-tea-spoons}"
tag_format="${TAG_FORMAT:-v{version}}"
overrides="${REPO_OVERRIDES:-{\"com.tea-spoons.ci-kit\":\"unity-ci-kit\"}}"
tf_version="${TEST_FRAMEWORK_VERSION:-1.4.6}"
prefix="com.${org}."

manifest="${pkg}/package.json"
[[ -f "$manifest" ]] || { echo "::error::${manifest} not found."; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name="$(jq -r .name "$manifest")"
version="$(jq -r .version "$manifest")"

repo_for() {
  local dep="$1" override
  override="$(jq -r --arg k "$dep" '.[$k] // empty' <<< "$overrides")"
  if [[ -n "$override" ]]; then printf '%s' "$override"; return; fi
  printf '%s' "${dep#"$prefix"}"
}

echo "Preparing isolated install of ${name}@${version} in ${project}"
rm -rf "$project"
mkdir -p "$project/Packages" "$project/ProjectSettings" "$project/Assets"
cp "${script_dir}/../examples/sample-project/ProjectSettings/ProjectVersion.txt" "$project/ProjectSettings/ProjectVersion.txt"

# Embed the package under test. Its own folder name doesn't matter to Unity, only that
# package.json sits at the top of it; strip .git so the throwaway project has no nested repo.
dest="$project/Packages/${name}"
mkdir -p "$dest"
cp -a "${pkg}/." "$dest/"
rm -rf "${dest}/.git"

deps="$(jq -c '.dependencies // {}' "$manifest")"
manifest_deps="$(jq -n --arg n "$name" --arg v "$version" --arg tf "$tf_version" \
  '{ ($n): $v, "com.unity.test-framework": $tf }')"

for dep in $(jq -r 'keys[]' <<< "$deps"); do
  dep_version="$(jq -r --arg k "$dep" '.[$k]' <<< "$deps")"
  manifest_deps="$(jq --arg k "$dep" --arg v "$dep_version" '. + {($k): $v}' <<< "$manifest_deps")"

  if [[ "$dep" != "$prefix"* ]]; then
    echo "  ${dep}@${dep_version} -> registry (declared as-is)"
    continue
  fi

  repo="$(repo_for "$dep")"
  tag="${tag_format//\{name\}/$dep}"; tag="${tag//\{version\}/$dep_version}"
  remote="https://github.com/${org}/${repo}.git"
  echo "  ${dep}@${dep_version} -> embedding github.com/${org}/${repo}@${tag}"

  sibling_clone="$(mktemp -d)"
  if ! git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$tag" "$remote" "$sibling_clone" 2>/dev/null; then
    # The pinned version was never tagged (a stale dependency pin, not a contamination bug).
    # Fall back to the sibling's latest tag - or its default branch if it has none - and warn
    # instead of failing, so this check still verifies what it's actually for.
    rm -rf "$sibling_clone"; sibling_clone="$(mktemp -d)"
    latest_tag="$(git ls-remote --tags --refs --sort=-v:refname "$remote" 2>/dev/null | head -n1 | sed 's#.*refs/tags/##')"
    if [[ -n "$latest_tag" ]]; then
      echo "::warning::${org}/${repo} has no tag '${tag}' for declared dependency ${dep}@${dep_version} of ${name}; using its latest tag '${latest_tag}' instead. The pinned version in package.json is stale."
      git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$latest_tag" "$remote" "$sibling_clone" \
        || { echo "::error::Could not clone ${org}/${repo} at its latest tag '${latest_tag}' either."; exit 1; }
    else
      echo "::warning::${org}/${repo} has no tags at all; using its default branch for declared dependency ${dep}@${dep_version} of ${name}."
      git -c advice.detachedHead=false clone --quiet --depth 1 "$remote" "$sibling_clone" \
        || { echo "::error::Could not clone ${org}/${repo} (no tags, default branch clone also failed)."; exit 1; }
    fi
  fi

  # The dependency's package.json may be at the repo root or nested (e.g. Packages/<name>),
  # same as the package under test can be. Find it instead of assuming root.
  sibling_pkg_json="$(find "$sibling_clone" -maxdepth 4 -name package.json -exec grep -l "\"name\": *\"${dep}\"" {} + | head -n1)"
  if [[ -z "$sibling_pkg_json" ]]; then
    echo "::error::${org}/${repo}@${tag} does not contain a package.json for ${dep}."
    exit 1
  fi
  sibling_pkg_dir="$(dirname "$sibling_pkg_json")"

  sibling_dest="$project/Packages/${dep}"
  mkdir -p "$sibling_dest"
  cp -a "${sibling_pkg_dir}/." "$sibling_dest/"
  rm -rf "$sibling_clone"
done

jq -n --argjson deps "$manifest_deps" --arg testable "$name" \
  '{dependencies: $deps, testables: [$testable]}' > "$project/Packages/manifest.json"

echo "Isolated project ready: $(jq -c '.dependencies | keys' "$project/Packages/manifest.json")"
