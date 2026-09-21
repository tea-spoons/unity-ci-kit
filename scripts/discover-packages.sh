#!/usr/bin/env bash
# Finds every UPM package in a GitHub org's repos: one with package.json at its root, or
# nested under a Packages/ folder (as unity-ci-kit itself is). Prints a JSON array of
# {"repo": "...", "path": "..."} objects, ready for a GitHub Actions matrix.
#
# Usage: discover-packages.sh [org]
# Needs: gh (authenticated), jq.
set -euo pipefail

org="${1:-tea-spoons}"

repos="$(gh repo list "$org" --limit 200 --json name,isArchived,isFork \
  --jq '.[] | select(.isArchived | not) | select(.isFork | not) | .name')"

packages="[]"
while IFS= read -r repo; do
  [[ -z "$repo" || "$repo" == ".github" ]] && continue

  if gh api "repos/${org}/${repo}/contents/package.json" > /dev/null 2>&1; then
    packages="$(jq -c --arg repo "$repo" --arg path "." '. + [{repo: $repo, path: $path}]' <<< "$packages")"
    continue
  fi

  subdirs="$(gh api "repos/${org}/${repo}/contents/Packages" --jq '.[].name' 2>/dev/null || true)"
  while IFS= read -r sub; do
    [[ -z "$sub" ]] && continue
    if gh api "repos/${org}/${repo}/contents/Packages/${sub}/package.json" > /dev/null 2>&1; then
      packages="$(jq -c --arg repo "$repo" --arg path "Packages/${sub}" '. + [{repo: $repo, path: $path}]' <<< "$packages")"
    fi
  done <<< "$subdirs"
done <<< "$repos"

jq -c . <<< "$packages"
