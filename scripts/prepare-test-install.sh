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
# NOT `"${TAG_FORMAT:-v{version}}"`: bash's `${VAR:-word}` mis-parses a `word` containing a
# literal, unescaped `}` - it closes the expansion one `}` early and appends the rest as a
# literal suffix, silently corrupting the result even when the variable IS set (e.g. yielding
# "v{version}}" here). Check emptiness explicitly instead.
tag_format="${TAG_FORMAT:-}"; [[ -n "$tag_format" ]] || tag_format='v{version}'
overrides="${REPO_OVERRIDES:-}"
[[ -n "$overrides" ]] || overrides='{"com.tea-spoons.ci-kit":"unity-ci-kit"}'
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

# Snapshot the package into an external staging dir BEFORE touching $project. $project is
# commonly created as a subdirectory of the checked-out repo (e.g. package-path "." with
# project-path ".test-install-project"), so copying "$pkg" straight into "$project/Packages/..."
# after $project exists can mean copying a directory into its own descendant.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp -a "${pkg}/." "$stage/"
rm -rf "${stage}/.git"

rm -rf "$project"
mkdir -p "$project/Packages" "$project/ProjectSettings" "$project/Assets"
cp "${script_dir}/../examples/sample-project/ProjectSettings/ProjectVersion.txt" "$project/ProjectSettings/ProjectVersion.txt"

# Embed the package under test. Its own folder name doesn't matter to Unity, only that
# package.json sits at the top of it.
dest="$project/Packages/${name}"
mkdir -p "$dest"
cp -a "${stage}/." "$dest/"

deps="$(jq -c '.dependencies // {}' "$manifest")"
manifest_deps="$(jq -n --arg n "$name" --arg v "$version" --arg tf "$tf_version" \
  '{ ($n): $v, "com.unity.test-framework": $tf }')"

# Unity's package resolver hard-fails the WHOLE project if any embedded package (including a
# sibling we embedded) declares a dependency that isn't present - so a sibling's own declared
# dependencies have to be embedded too, transitively, not just the target package's direct ones.
# (No associative arrays: this needs to run under bash 3.2, which is what macOS still ships.)
embedded=$'\n'
queue=()

is_embedded() { [[ "$embedded" == *$'\n'"$1"$'\n'* ]]; }
mark_embedded() { embedded+="$1"$'\n'; }

enqueue_deps() {
  local deps_json="$1" dep dep_version
  for dep in $(jq -r 'keys[]' <<< "$deps_json"); do
    dep_version="$(jq -r --arg k "$dep" '.[$k]' <<< "$deps_json")"
    queue+=("${dep}"$'\t'"${dep_version}")
  done
}

enqueue_deps "$deps"

while [[ ${#queue[@]} -gt 0 ]]; do
  entry="${queue[0]}"; queue=("${queue[@]:1}")
  dep="${entry%%$'\t'*}"; dep_version="${entry#*$'\t'}"

  if [[ "$dep" != "$prefix"* ]]; then
    # A plain registry package: just declare it, once (first declared version wins if it
    # appears more than once across the dependency graph).
    if ! jq -e --arg k "$dep" 'has($k)' <<< "$manifest_deps" > /dev/null; then
      manifest_deps="$(jq --arg k "$dep" --arg v "$dep_version" '. + {($k): $v}' <<< "$manifest_deps")"
      echo "  ${dep}@${dep_version} -> registry (declared as-is)"
    fi
    continue
  fi

  # Already embedded (or being embedded) - skip, both to dedupe and to guard against a cycle.
  is_embedded "$dep" && continue
  mark_embedded "$dep"
  manifest_deps="$(jq --arg k "$dep" --arg v "$dep_version" '. + {($k): $v}' <<< "$manifest_deps")"

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
      echo "::warning::${org}/${repo} has no tag '${tag}' for declared dependency ${dep}@${dep_version}; using its latest tag '${latest_tag}' instead. The pinned version in package.json is stale."
      git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$latest_tag" "$remote" "$sibling_clone" \
        || { echo "::error::Could not clone ${org}/${repo} at its latest tag '${latest_tag}' either."; exit 1; }
    else
      echo "::warning::${org}/${repo} has no tags at all; using its default branch for declared dependency ${dep}@${dep_version}."
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

  enqueue_deps "$(jq -c '.dependencies // {}' "${sibling_pkg_dir}/package.json")"
  rm -rf "$sibling_clone"
done

jq -n --argjson deps "$manifest_deps" --arg testable "$name" \
  '{dependencies: $deps, testables: [$testable]}' > "$project/Packages/manifest.json"

echo "Isolated project ready: $(jq -c '.dependencies | keys' "$project/Packages/manifest.json")"
