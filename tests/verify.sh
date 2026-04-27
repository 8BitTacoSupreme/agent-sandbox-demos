#!/usr/bin/env bash
# =============================================================================
# verify.sh — test that the sandbox actually blocks what it claims to block
# =============================================================================
# Run this from inside a sandboxed shell (after agent-sbx elevate). It tries
# every escape vector in the sandflox threat model and reports which were
# blocked vs which got through.
#
# Pass: every BLOCK test was blocked, every ALLOW test succeeded.
# Fail: any BLOCK test got through (sandbox is broken) OR any ALLOW test
#       was blocked (sandbox is too restrictive for normal work).
# =============================================================================

set +e  # we expect things to fail

PASS=0
FAIL=0
PLATFORM="$(uname)"

# Color codes (auto-disable if not a TTY)
if [[ -t 1 ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; DIM=""; RESET=""
fi

# expect_block CMD DESC — command should fail (sandbox catches it)
expect_block() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "${RED}FAIL${RESET}  expected blocked: $desc"
    FAIL=$((FAIL+1))
  else
    echo "${GREEN}PASS${RESET}  blocked: $desc"
    PASS=$((PASS+1))
  fi
}

# expect_allow CMD DESC — command should succeed (sandbox lets it through)
expect_allow() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "${GREEN}PASS${RESET}  allowed: $desc"
    PASS=$((PASS+1))
  else
    echo "${RED}FAIL${RESET}  expected allowed: $desc"
    FAIL=$((FAIL+1))
  fi
}

echo "${DIM}── Verifying sandbox enforcement (${PLATFORM}) ──${RESET}"
echo

# ── BLOCK: package managers (shell-tier function armor) ──
expect_block "pip install requests"             pip install requests
expect_block "npm install lodash"               npm install lodash
expect_block "brew install nmap"                brew install nmap
expect_block "cargo install ripgrep"            cargo install ripgrep
expect_block "go install something"             go install ./...

# ── BLOCK: filesystem writes outside workspace (kernel-tier) ──
expect_block "write to /etc"                    bash -c 'echo pwned > /etc/test 2>/dev/null'
expect_block "write to /usr/local"              bash -c 'echo pwned > /usr/local/test 2>/dev/null'
expect_block "write to ~ (home root)"           bash -c "echo pwned > $HOME/agent-sbx-escape-test 2>/dev/null"

# ── BLOCK: reads to credential paths (kernel-tier) ──
expect_block "read ~/.ssh/id_rsa"               cat "$HOME/.ssh/id_rsa"
expect_block "read ~/.aws/credentials"          cat "$HOME/.aws/credentials"
expect_block "list ~/.gnupg"                    ls "$HOME/.gnupg"

# ── BLOCK: network (kernel-tier) ──
expect_block "curl example.com"                 curl --max-time 3 https://example.com
expect_block "python socket connect"            python3 -c 'import socket; socket.create_connection(("example.com",80), timeout=3)'

# ── BLOCK: python escape vectors (shell-tier python wrapper) ──
expect_block "python3 -m pip"                   python3 -m pip install requests
expect_block "python3 -m ensurepip"             python3 -m ensurepip
expect_block "python3 -m venv"                  python3 -m venv /tmp/escape-venv

# ── ALLOW: workspace operations ──
expect_allow "write to ./test.tmp"              bash -c 'echo ok > ./agent-sbx-test.tmp'
expect_allow "read ./README.md"                 test -f README.md
# /tmp path: macOS resolves to /private/tmp, Linux uses /tmp directly
expect_allow "write to /tmp"                    bash -c 'echo ok > /tmp/agent-sbx-test.tmp'
expect_allow "git status"                       git status

# ── ALLOW: pure computation ──
expect_allow "python3 arithmetic"               python3 -c 'print(2+2)'
if command -v node >/dev/null 2>&1; then
  expect_allow "node arithmetic"                  node -e 'console.log(2+2)'
else
  echo "${DIM}SKIP${RESET}  node not on PATH — skipping node arithmetic test"
fi
expect_allow "jq filter"                        bash -c 'echo {} | jq .'

# Cleanup
rm -f ./agent-sbx-test.tmp /tmp/agent-sbx-test.tmp 2>/dev/null

echo
echo "${DIM}── Results ──${RESET}"
TOTAL=$((PASS+FAIL))
if [[ $FAIL -eq 0 ]]; then
  echo "${GREEN}$PASS / $TOTAL passed.${RESET} Sandbox is enforcing as expected."
  exit 0
else
  echo "${RED}$FAIL / $TOTAL failed.${RESET} Sandbox is not behaving as expected."
  exit 1
fi
