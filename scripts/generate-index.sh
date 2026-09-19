#!/usr/bin/env bash
# Builds a small package index (index.json + index.html) from one or more UPM package folders.
# The page lists each package with a copy-ready Package Manager git URL, so a repo of packages
# can be published with GitHub Pages and shared as a single link.
#
# Usage: generate-index.sh <output-dir> <package-dir>...
#
#   REPO_URL   Repository URL used to build install URLs (default: https://github.com/$GITHUB_REPOSITORY)
#   REF        Optional tag or branch appended to install URLs, e.g. v0.1.0
#   TITLE      Page title (default: Unity packages)
# Needs: jq.
set -euo pipefail

out="${1:?usage: generate-index.sh <output-dir> <package-dir>...}"
shift
[[ $# -gt 0 ]] || { echo "::error::Give at least one package directory." >&2; exit 64; }

repo_url="${REPO_URL:-https://github.com/${GITHUB_REPOSITORY:?Set REPO_URL or GITHUB_REPOSITORY}}"
ref="${REF:-}"
title="${TITLE:-Unity packages}"

mkdir -p "$out"

entries=()
for pkg in "$@"; do
  pkg="${pkg%/}"
  [[ -f "$pkg/package.json" ]] || { echo "::error::$pkg/package.json not found." >&2; exit 65; }
  rel="${pkg#./}"
  install="${repo_url}.git"
  [[ "$rel" != "." ]] && install+="?path=/${rel}"
  [[ -n "$ref" ]] && install+="#${ref}"
  entries+=("$(jq --arg install "$install" --arg path "$rel" \
    '{name, displayName: (.displayName // .name), version, description: (.description // ""),
      unity: (.unity // ""), path: $path, install: $install}' "$pkg/package.json")")
done

printf '%s\n' "${entries[@]}" | jq -s '.' > "$out/index.json"

jq -r --arg title "$title" '
  def card: "<article><h2>\(.displayName | @html) <small>\(.version | @html)</small></h2>"
    + "<p>\(.description | @html)</p>"
    + (if .unity != "" then "<p class=meta>Unity \(.unity | @html)+ &middot; <code>\(.name | @html)</code></p>" else "" end)
    + "<input readonly value=\"\(.install | @html)\" onclick=\"this.select()\"></article>";
  "<!doctype html><html lang=en><head><meta charset=utf-8>"
  + "<meta name=viewport content=\"width=device-width,initial-scale=1\">"
  + "<title>\($title | @html)</title><style>"
  + "body{font:16px/1.5 system-ui,sans-serif;max-width:46rem;margin:2rem auto;padding:0 1rem}"
  + "article{border:1px solid #8884;border-radius:8px;padding:1rem;margin:1rem 0}"
  + "h2{margin:0;font-size:1.15rem}small{font-weight:400;opacity:.7}.meta{opacity:.7;font-size:.9rem}"
  + "input{width:100%;box-sizing:border-box;font:13px ui-monospace,monospace;padding:.4rem}"
  + "</style></head><body><h1>\($title | @html)</h1>"
  + "<p>Unity Package Manager &rarr; <b>Add package from git URL</b>, then paste a URL below.</p>"
  + (map(card) | join(""))
  + "</body></html>"
' "$out/index.json" > "$out/index.html"

echo "Wrote $out/index.json and $out/index.html for $# package(s)."
