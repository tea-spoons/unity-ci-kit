#!/usr/bin/env bash
# Checks scripts/prepare-test-install.sh. The dependency-resolving checks need network access
# to github.com/tea-spoons and are skipped (not failed) when that isn't reachable.
# Usage: bash tests/prepare-test-install.test.sh
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prepare="$repo/scripts/prepare-test-install.sh"
good="$repo/Packages/com.tea-spoons.ci-kit" # no declared dependencies - exercises the local-only path
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
ok()   { echo "ok:   $1"; }
fail() { echo "FAIL: $1"; shift; [[ $# -gt 0 ]] && printf '%s\n' "$@" | sed 's/^/    /'; failures=$((failures + 1)); }

# A package with no dependencies embeds only itself and the test framework.
out="$(bash "$prepare" "$good" "$work/proj1" 2>&1)"; rc=$?
if [[ $rc -eq 0 ]] \
  && [[ -d "$work/proj1/Assets" ]] \
  && [[ -f "$work/proj1/Packages/com.tea-spoons.ci-kit/package.json" ]] \
  && jq -e '.dependencies["com.tea-spoons.ci-kit"] and .dependencies["com.unity.test-framework"]' "$work/proj1/Packages/manifest.json" > /dev/null; then
  ok "package with no dependencies embeds itself + test-framework only"
else
  fail "package with no dependencies embeds itself + test-framework only" "$out"
fi

# package-path "." with the project directory created *inside* it (exactly what CI does when
# a package sits at its repo's root) must not try to copy the package into its own descendant.
mkdir -p "$work/root-pkg"
cp -a "$good/." "$work/root-pkg/"
( cd "$work/root-pkg" && out="$(bash "$prepare" "." ".test-install-project" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]] && [[ -f ".test-install-project/Packages/com.tea-spoons.ci-kit/package.json" ]]; then
    echo "ok:   package-path . with a project dir nested inside it doesn't self-copy"
  else
    echo "FAIL: package-path . with a project dir nested inside it doesn't self-copy"
    printf '%s\n' "$out" | sed 's/^/    /'
    exit 1
  fi
) || failures=$((failures + 1))

# Missing package.json is reported and nothing is left half-built.
out="$(bash "$prepare" "$work/does-not-exist" "$work/proj2" 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *"not found"* ]]; then
  ok "missing package.json is reported"
else
  fail "missing package.json is reported" "$out"
fi

if git ls-remote --exit-code https://github.com/tea-spoons/large-numbers.git > /dev/null 2>&1; then
  mkdir -p "$work/net-pkg"
  cat > "$work/net-pkg/package.json" <<'EOF'
{
  "name": "com.tea-spoons.__test-install-fixture",
  "version": "0.0.1",
  "displayName": "Test Install Fixture",
  "description": "Synthetic package used only by prepare-test-install.test.sh.",
  "dependencies": { "com.tea-spoons.large-numbers": "0.7.2" }
}
EOF
  out="$(bash "$prepare" "$work/net-pkg" "$work/proj3" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]] \
    && [[ -f "$work/proj3/Packages/com.tea-spoons.large-numbers/package.json" ]] \
    && jq -e '.dependencies["com.tea-spoons.large-numbers"] == "0.7.2"' "$work/proj3/Packages/manifest.json" > /dev/null; then
    ok "a declared tea-spoons dependency at a real tag is embedded"
  else
    fail "a declared tea-spoons dependency at a real tag is embedded" "$out"
  fi

  # actions/test-install always exports TAG_FORMAT and REPO_OVERRIDES (even at their default
  # values) rather than leaving them unset - a prior bug only showed up in that exact case
  # (bash's `${VAR:-word}` silently corrupts `word` when VAR IS set and `word` has a literal
  # `}` in it), so exercise the same shape here instead of only the unset-default path above.
  out="$(TAG_FORMAT='v{version}' REPO_OVERRIDES='{"com.tea-spoons.ci-kit":"unity-ci-kit"}' \
    bash "$prepare" "$work/net-pkg" "$work/proj3b" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]] \
    && [[ -f "$work/proj3b/Packages/com.tea-spoons.large-numbers/package.json" ]] \
    && [[ "$out" != *"::warning::"* ]]; then
    ok "TAG_FORMAT/REPO_OVERRIDES exported at their default values still resolve the exact tag"
  else
    fail "TAG_FORMAT/REPO_OVERRIDES exported at their default values still resolve the exact tag" "$out"
  fi

  mkdir -p "$work/stale-pkg"
  cat > "$work/stale-pkg/package.json" <<'EOF'
{
  "name": "com.tea-spoons.__test-install-fixture-stale",
  "version": "0.0.1",
  "displayName": "Test Install Fixture (stale pin)",
  "description": "Synthetic package used only by prepare-test-install.test.sh.",
  "dependencies": { "com.tea-spoons.large-numbers": "0.0.1-does-not-exist" }
}
EOF
  out="$(bash "$prepare" "$work/stale-pkg" "$work/proj4" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]] \
    && [[ "$out" == *"::warning::"*"has no tag"* ]] \
    && [[ -f "$work/proj4/Packages/com.tea-spoons.large-numbers/package.json" ]]; then
    ok "an unpublished pinned version falls back to the sibling's latest tag, with a warning"
  else
    fail "an unpublished pinned version falls back to the sibling's latest tag, with a warning" "$out"
  fi
else
  echo "skip: github.com/tea-spoons is not reachable, skipping dependency-resolution checks"
fi

if [[ $failures -gt 0 ]]; then echo "$failures check(s) failed."; exit 1; fi
echo "All prepare-test-install checks passed."
