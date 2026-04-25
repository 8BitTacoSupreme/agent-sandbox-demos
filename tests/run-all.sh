#!/usr/bin/env bash
# =============================================================================
# run-all.sh — test every demo whose env manager is installed
# =============================================================================
# Runs sbx prepare + elevate + verify.sh for each demo. Skips demos whose
# env manager isn't found on PATH. Reports per-demo pass/fail/skip.
#
# Usage:
#   ./tests/run-all.sh           # from agent-sandbox-demos/
#   ./tests/run-all.sh plain-shell devbox   # run only named demos
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SBX="$REPO_DIR/sbx/sbx"
VERIFY="$SCRIPT_DIR/verify.sh"

# Color codes
if [[ -t 1 ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; DIM=""; RESET=""
fi

PASSED=() FAILED=() SKIPPED=()

# ─────────────────────────────────────────────────────────────────────────────
# Per-demo test runner
# ─────────────────────────────────────────────────────────────────────────────

run_demo() {
  local name="$1" dir="$REPO_DIR/demos/$name"

  [[ -d "$dir" ]] || { echo "${RED}ERROR${RESET}  demos/$name: directory not found"; FAILED+=("$name"); return; }

  echo "${DIM}── Testing demos/$name ──${RESET}"

  # Each demo needs sbx prepare to run inside the demo dir
  cd "$dir" || { FAILED+=("$name"); return; }

  # Run sbx prepare
  if ! "$SBX" prepare 2>&1; then
    echo "${RED}FAIL${RESET}  demos/$name: sbx prepare failed"
    FAILED+=("$name")
    return
  fi

  # Run verify.sh inside sandbox-exec (kernel enforcement)
  local result
  result=$(env SBX_ACTIVE=1 PATH="$dir/.sandbox/bin" \
    sandbox-exec -f "$dir/.sandbox/profile.sb" \
    bash --rcfile "$dir/.sandbox/armor.bash" -ic "source '$dir/.sandbox/armor.bash' && '$VERIFY'" 2>&1)
  local rc=$?

  echo "$result"

  if [[ $rc -eq 0 ]]; then
    echo "${GREEN}PASS${RESET}  demos/$name"
    PASSED+=("$name")
  else
    echo "${RED}FAIL${RESET}  demos/$name"
    FAILED+=("$name")
  fi
  echo
}

skip_demo() {
  local name="$1" reason="$2"
  echo "${YELLOW}SKIP${RESET}  demos/$name — $reason"
  SKIPPED+=("$name")
}

# ─────────────────────────────────────────────────────────────────────────────
# Demo dispatch — detect env manager, activate, test
# ─────────────────────────────────────────────────────────────────────────────

test_plain_shell() {
  # No env manager needed — uses whatever's on PATH
  run_demo "plain-shell"
}

test_flox() {
  if ! command -v flox >/dev/null 2>&1; then
    skip_demo "flox" "flox not installed"
    return
  fi
  skip_demo "flox" "sandflox binary requires separate build (see demos/flox/README.md)"
}

test_devbox() {
  if ! command -v devbox >/dev/null 2>&1; then
    skip_demo "devbox" "devbox not installed"
    return
  fi
  run_demo "devbox"
}

test_determinate_nix() {
  if ! command -v nix >/dev/null 2>&1; then
    skip_demo "determinate-nix" "nix not installed"
    return
  fi
  run_demo "determinate-nix"
}

test_direnv_nix() {
  if ! command -v direnv >/dev/null 2>&1; then
    skip_demo "direnv-nix" "direnv not installed"
    return
  fi
  if ! command -v nix >/dev/null 2>&1; then
    skip_demo "direnv-nix" "nix not installed"
    return
  fi
  run_demo "direnv-nix"
}

test_mise() {
  if ! command -v mise >/dev/null 2>&1; then
    skip_demo "mise" "mise not installed"
    return
  fi
  run_demo "mise"
}

test_asdf() {
  if ! command -v asdf >/dev/null 2>&1; then
    skip_demo "asdf" "asdf not installed"
    return
  fi
  run_demo "asdf"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

ALL_DEMOS=(plain-shell flox devbox determinate-nix direnv-nix mise asdf)

# If arguments given, run only those demos
if [[ $# -gt 0 ]]; then
  SELECTED=("$@")
else
  SELECTED=("${ALL_DEMOS[@]}")
fi

echo "${DIM}═══════════════════════════════════════════════════════════════${RESET}"
echo " agent-sandbox-demos — test suite"
echo "${DIM}═══════════════════════════════════════════════════════════════${RESET}"
echo

for demo in "${SELECTED[@]}"; do
  case "$demo" in
    plain-shell)      test_plain_shell ;;
    flox)             test_flox ;;
    devbox)           test_devbox ;;
    determinate-nix)  test_determinate_nix ;;
    direnv-nix)       test_direnv_nix ;;
    mise)             test_mise ;;
    asdf)             test_asdf ;;
    *) echo "${RED}ERROR${RESET}  unknown demo: $demo"; FAILED+=("$demo") ;;
  esac
done

# ── Summary ──
echo "${DIM}═══════════════════════════════════════════════════════════════${RESET}"
echo " Results"
echo "${DIM}═══════════════════════════════════════════════════════════════${RESET}"
[[ ${#PASSED[@]}  -gt 0 ]] && echo "${GREEN}PASSED${RESET}:  ${PASSED[*]}"
[[ ${#SKIPPED[@]} -gt 0 ]] && echo "${YELLOW}SKIPPED${RESET}: ${SKIPPED[*]}"
[[ ${#FAILED[@]}  -gt 0 ]] && echo "${RED}FAILED${RESET}:  ${FAILED[*]}"
echo
echo "Total: ${#PASSED[@]} passed, ${#SKIPPED[@]} skipped, ${#FAILED[@]} failed"

[[ ${#FAILED[@]} -eq 0 ]]
