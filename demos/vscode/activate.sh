#!/usr/bin/env bash
# VS Code / Cursor terminal profile activation script.
#
# Launched by the "Sandboxed" terminal profile defined in .vscode/settings.json.
# Resolves its own location to find agent-sbx relative to the repo root,
# prepares the sandbox, then execs into an elevated (kernel-enforced) shell.

set -e

# ── Resolve script location ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT_SBX="$REPO_ROOT/agent-sbx/agent-sbx"

# ── Sanity checks ────────────────────────────────────────────────────────────
if [[ ! -x "$AGENT_SBX" ]]; then
  echo "ERROR: agent-sbx not found at $AGENT_SBX" >&2
  echo "       Clone the repo and ensure agent-sbx/agent-sbx exists." >&2
  exit 1
fi

need=(bash cat ls grep sed awk find git jq python3)
missing=()
for tool in "${need[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing required tools:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

# ── Prepare and elevate ──────────────────────────────────────────────────────
cd "$SCRIPT_DIR"
"$AGENT_SBX" prepare
exec "$AGENT_SBX" elevate
