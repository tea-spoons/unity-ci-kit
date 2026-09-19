#!/usr/bin/env bash
# Checks that a folder is a well-formed Unity package (UPM) that Package Manager will accept from git.
#
# Usage: validate-package.sh <package-dir>
# Needs: jq. Exits 1 when any error is found; warnings do not fail the run.
set -uo pipefail

dir="${1:?usage: validate-package.sh <package-dir>}"
dir="${dir%/}"
manifest="${dir}/package.json"
errors=0

error()   { echo "::error::$*"; errors=$((errors + 1)); }
warning() { echo "::warning::$*"; }

if [[ ! -f "$manifest" ]]; then
  error "${manifest} not found."
  exit 1
fi
if ! jq -e . "$manifest" > /dev/null 2>&1; then
  error "${manifest} is not valid JSON."
  exit 1
fi

field() { jq -r --arg k "$1" '.[$k] // empty' "$manifest"; }

name="$(field name)"
version="$(field version)"
unity="$(field unity)"

[[ "$name" =~ ^[a-z0-9-]+(\.[a-z0-9-]+)+$ ]] \
  || error "package.json name '${name}' must be lowercase dot-separated, like com.company.package."
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] \
  || error "package.json version '${version}' is not semantic (MAJOR.MINOR.PATCH)."
[[ -n "$(field displayName)" ]] || error "package.json is missing displayName."
[[ -n "$(field description)" ]] || error "package.json is missing description."
if [[ -n "$unity" ]] && ! [[ "$unity" =~ ^[0-9]{4}\.[0-9]+$ ]]; then
  error "package.json unity '${unity}' must look like 2021.3 or 6000.0."
fi

# Unity skips hidden items and folders ending in '~'; everything else needs a .meta.
while IFS= read -r -d '' path; do
  [[ "$path" == *.meta ]] && continue
  [[ -e "${path}.meta" ]] || error "Missing .meta file for ${path#"$dir"/}."
done < <(find "$dir" -mindepth 1 \( -name '.*' -o -name '*~' \) -prune -o -print0)

while IFS= read -r -d '' meta; do
  [[ -e "${meta%.meta}" ]] || error "Orphaned meta file ${meta#"$dir"/} (its asset does not exist)."
done < <(find "$dir" -mindepth 1 \( -name '.*' -o -name '*~' \) -prune -o -name '*.meta' -print0)

# A GUID used twice breaks references in the consuming project.
duplicates="$(
  find "$dir" -name '*.meta' -exec grep -H -m1 '^guid:' {} + 2>/dev/null \
    | awk -F': ' '{print $NF}' | sort | uniq -d
)"
if [[ -n "$duplicates" ]]; then
  error "Duplicate GUIDs in .meta files: $(echo "$duplicates" | tr '\n' ' ')"
fi

[[ -f "${dir}/README.md" ]]    || warning "Package has no README.md."
[[ -f "${dir}/LICENSE.md" || -f "${dir}/LICENSE" ]] || warning "Package has no LICENSE."
[[ -f "${dir}/CHANGELOG.md" ]] || warning "Package has no CHANGELOG.md."

if [[ $errors -gt 0 ]]; then
  echo "Package validation failed with ${errors} error(s)."
  exit 1
fi
echo "Package ${name}@${version} is valid."
