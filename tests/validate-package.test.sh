#!/usr/bin/env bash
# Checks scripts/validate-package.sh against the real package and deliberately broken copies.
# Usage: bash tests/validate-package.test.sh
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validate="$repo/scripts/validate-package.sh"
good="$repo/Packages/com.tea-spoons.ci-kit"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
expect() { # expect <description> <wanted-rc> <wanted-substring> <package-dir>
  local desc="$1" want_rc="$2" want_text="$3" dir="$4" out rc
  out="$(bash "$validate" "$dir" 2>&1)"; rc=$?
  if [[ $rc -ne $want_rc || "$out" != *"$want_text"* ]]; then
    echo "FAIL: $desc (exit $rc, wanted $want_rc, expected text: $want_text)"
    printf '%s\n' "$out" | sed 's/^/    /'; failures=$((failures + 1))
  else
    echo "ok:   $desc"
  fi
}

broken() { rm -rf "$work/pkg"; cp -R "$good" "$work/pkg"; }

expect "the kit's own package is valid" 0 "is valid" "$good"

broken; rm "$work/pkg/Editor/BuildRunner.cs.meta"
expect "missing .meta is reported" 1 "Missing .meta file for Editor/BuildRunner.cs" "$work/pkg"

broken; touch "$work/pkg/ghost.txt.meta"
expect "orphaned .meta is reported" 1 "Orphaned meta file ghost.txt.meta" "$work/pkg"

broken; sed -i 's/"version": "[^"]*"/"version": "one"/' "$work/pkg/package.json"
expect "non-semantic version is reported" 1 "is not semantic" "$work/pkg"

broken; sed -i 's/"name": "com.tea-spoons.ci-kit"/"name": "NotValid"/' "$work/pkg/package.json"
expect "bad package name is reported" 1 "must be lowercase dot-separated" "$work/pkg"

broken; cp "$work/pkg/Editor/CiArguments.cs.meta" "$work/pkg/Tests/Editor/CiArgumentsTests.cs.meta"
expect "duplicate GUIDs are reported" 1 "Duplicate GUIDs" "$work/pkg"

broken; rm "$work/pkg/package.json"
expect "missing package.json is reported" 1 "not found" "$work/pkg"

if [[ $failures -gt 0 ]]; then echo "$failures check(s) failed."; exit 1; fi
echo "All validate-package checks passed."
