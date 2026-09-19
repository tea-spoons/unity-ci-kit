#!/usr/bin/env bash
# Prints a markdown table of NUnit result files found in a directory.
# Appends to $GITHUB_STEP_SUMMARY when it is set, otherwise prints to stdout.
#
# Usage: summarize-tests.sh <results-dir>
set -uo pipefail

dir="${1:?usage: summarize-tests.sh <results-dir>}"
out="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

# Reads one attribute from the <test-run ...> root element of an NUnit 3 file.
attr() {
  local file="$1" name="$2"
  grep -m1 -o "<test-run [^>]*>" "$file" | grep -o "${name}=\"[^\"]*\"" | head -n1 | cut -d'"' -f2
}

shopt -s nullglob
files=("$dir"/*.xml)

{
  echo "### Unity test results"
  if [[ ${#files[@]} -eq 0 ]]; then
    echo
    echo "No result files were produced in \`$dir\`."
    exit 0
  fi
  echo
  echo "| Run | Result | Total | Passed | Failed | Skipped |"
  echo "|-----|--------|------:|-------:|-------:|--------:|"
  for f in "${files[@]}"; do
    name="$(basename "$f" .xml)"
    result="$(attr "$f" result)"
    printf '| %s | %s | %s | %s | %s | %s |\n' \
      "$name" "${result:-?}" \
      "$(attr "$f" total)" "$(attr "$f" passed)" "$(attr "$f" failed)" "$(attr "$f" skipped)"
  done
} >> "$out"
