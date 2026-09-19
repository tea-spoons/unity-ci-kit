#!/usr/bin/env bash
# Exercises scripts/run-unity.sh + scripts/container-entry.sh with a fake editor, so no Unity or license is needed.
# Needs Docker. Usage: bash tests/run-unity.test.sh
set -uo pipefail
export MSYS_NO_PATHCONV=1   # keep Git Bash on Windows from rewriting container paths

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/proj"
workspace="$(cd "$work" && (pwd -W 2>/dev/null || pwd))"

cat > "$work/fake-unity.sh" <<'EOF'
#!/usr/bin/env bash
printf 'ARGS:'; printf ' [%s]' "$@"; echo
if [[ -f "$HOME/.local/share/unity3d/Unity/Unity_lic.ulf" ]]; then
  echo "LICENSE: $(cat "$HOME/.local/share/unity3d/Unity/Unity_lic.ulf")"
fi
# Account login without a serial is Personal activation; the editor reports a grant like this.
if [[ " $* " == *" -username "* && " $* " != *" -serial "* && " $* " != *" -returnlicense "* \
      && ! -f /github/workspace/no-grant ]]; then
  echo "Serial number assigned to: fake-seat"
fi
[[ " $* " == *" -fail "* ]] && exit 3
exit 0
EOF
chmod +x "$work/fake-unity.sh"

# Stand-in for Unity.Licensing.Client: answers --help like a modern client and records every call.
cat > "$work/fake-client.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--help" ]]; then echo "  --include-personal   Fallback to Personal Edition"; exit 0; fi
printf 'CLIENT:'; printf ' [%s]' "$@"; echo
if [[ "$1" == "--return-ulf" && -f /github/workspace/no-ulf ]]; then
  echo "Ulf license file not found (1404)"; exit 1
fi
if [[ "$1" == "--activate-all" ]]; then
  if [[ -f /github/workspace/no-seat ]]; then echo "No seat available."; else echo "Seat ID: fake-seat"; fi
fi
exit 0
EOF
chmod +x "$work/fake-client.sh"

failures=0
indent() { sed 's/^/    /'; }
check() { # check <description> <expected-rc> <expected-substring|""> <actual-rc> <output>
  local desc="$1" want_rc="$2" want_text="$3" rc="$4" out="$5"
  if [[ "$rc" != "$want_rc" ]]; then
    echo "FAIL: $desc (exit $rc, wanted $want_rc)"; printf '%s\n' "$out" | indent; failures=$((failures + 1)); return
  fi
  if [[ -n "$want_text" && "$out" != *"$want_text"* ]]; then
    echo "FAIL: $desc (output lacks: $want_text)"; printf '%s\n' "$out" | indent; failures=$((failures + 1)); return
  fi
  echo "ok:   $desc"
}

run() { # run <env assignments...>; prints output, sets $rc
  out="$(env WORKSPACE="$workspace" UNITY_IMAGE=ubuntu:22.04 UNITY_BIN=/github/workspace/fake-unity.sh \
        PROJECT_PATH=proj "$@" bash "$repo/scripts/run-unity.sh" 2>&1)"
  rc=$?
}

run UNITY_COMMANDS=$'-runTests -testPlatform EditMode\n-coverageOptions "a;b c" -x\\;y'
check "runs each row with -projectPath and -logFile" 0 "[-projectPath] [proj] [-logFile] [/dev/stdout] [-runTests]" "$rc" "$out"
check "keeps quoted arguments together" 0 "[-coverageOptions] [a;b c] [-x;y]" "$rc" "$out"

run UNITY_COMMANDS=$'-fail\n-second'
check "stops at the first failing row" 3 "Unity exited with code 3" "$rc" "$out"
if [[ "$out" != *"[-second]"* ]]; then
  echo "ok:   later rows are skipped"
else
  echo "FAIL: later rows ran"; failures=$((failures + 1))
fi

run CONTINUE_ON_ERROR=1 UNITY_COMMANDS=$'-fail\n-second'
check "continue-on-error runs every row and returns the worst code" 3 "[-second]" "$rc" "$out"

run LICENSE_MODE=ulf UNITY_LICENSE='<license-body/>' UNITY_COMMANDS='-x'
check "ulf mode writes the license file" 0 "LICENSE: <license-body/>" "$rc" "$out"

run LICENSE_MODE=ulf UNITY_COMMANDS='-x'
check "ulf mode without a license fails" 65 "UNITY_LICENSE is empty" "$rc" "$out"

run LICENSE_MODE=personal UNITY_EMAIL=me@example.com UNITY_COMMANDS='-x'
check "personal mode without a password fails" 65 "UNITY_PASSWORD is empty" "$rc" "$out"

# Personal, older editors: activation goes through the editor (no licensing client in the image).
run LICENSE_MODE=personal UNITY_EMAIL=me@example.com UNITY_PASSWORD=pw UNITY_COMMANDS='-x'
check "personal (editor route) logs in with the account" 0 "[-username] [me@example.com] [-password] [pw]" "$rc" "$out"
if [[ "$out" != *"[-serial]"* ]]; then
  echo "ok:   personal activation passes no -serial"
else
  echo "FAIL: personal activation passed -serial"; failures=$((failures + 1))
fi
check "personal (editor route) returns the seat afterwards" 0 "[-returnlicense]" "$rc" "$out"

touch "$work/no-grant"
run LICENSE_MODE=personal UNITY_EMAIL=me@example.com UNITY_PASSWORD=pw UNITY_COMMANDS='-x' \
  LICENSE_ACTIVATION_ATTEMPTS=2 LICENSE_ACTIVATION_RETRY_DELAY=0
check "personal (editor route) fails when Unity grants no seat" 66 "did not grant a Personal seat" "$rc" "$out"
check "and retries before giving up" 66 "retrying in 0s" "$rc" "$out"
if [[ "$out" != *"[-projectPath]"* ]]; then
  echo "ok:   no Unity run starts without a seat"
else
  echo "FAIL: Unity ran without a license"; failures=$((failures + 1))
fi
rm -f "$work/no-grant"

# Personal, current editors: the licensing client requests the seat and gives it back.
run LICENSE_MODE=personal UNITY_EMAIL=me@example.com UNITY_PASSWORD=pw UNITY_COMMANDS='-x' \
  LICENSING_CLIENT=/github/workspace/fake-client.sh
check "personal (client route) activates through the licensing client" 0 \
  "CLIENT: [--activate-all] [--include-personal] [--username] [me@example.com] [--password] [pw]" "$rc" "$out"
check "personal (client route) returns the seat with --return-ulf" 0 "CLIENT: [--return-ulf]" "$rc" "$out"
if [[ "$out" != *"[-username]"* ]]; then
  echo "ok:   client route does not log in through the editor"
else
  echo "FAIL: client route also used the editor login"; failures=$((failures + 1))
fi

# Entitlement-based seats have no ULF file: --return-ulf fails, so the seat is returned through the editor.
touch "$work/no-ulf"
run LICENSE_MODE=personal UNITY_EMAIL=me@example.com UNITY_PASSWORD=pw UNITY_COMMANDS='-x' \
  LICENSING_CLIENT=/github/workspace/fake-client.sh
check "client route falls back to the editor when --return-ulf finds no ULF" 0 "Returning the seat through the editor" "$rc" "$out"
check "and returns the seat with -returnlicense" 0 "[-returnlicense] [-username] [me@example.com]" "$rc" "$out"
rm -f "$work/no-ulf"

touch "$work/no-seat"
run LICENSE_MODE=personal UNITY_EMAIL=me@example.com UNITY_PASSWORD=pw UNITY_COMMANDS='-x' \
  LICENSING_CLIENT=/github/workspace/fake-client.sh LICENSE_ACTIVATION_ATTEMPTS=1
check "personal (client route) fails when the client reports no seat" 66 "did not grant a Personal seat" "$rc" "$out"
rm -f "$work/no-seat"

run LICENSE_MODE=serial UNITY_SERIAL=s UNITY_EMAIL=e UNITY_COMMANDS='-x'
check "serial mode without a password fails" 65 "UNITY_PASSWORD is empty" "$rc" "$out"

run LICENSE_MODE=bogus UNITY_COMMANDS='-x'
check "unknown license mode fails" 64 "Unknown LICENSE_MODE" "$rc" "$out"

if [[ $failures -gt 0 ]]; then echo "$failures check(s) failed."; exit 1; fi
echo "All run-unity checks passed."
