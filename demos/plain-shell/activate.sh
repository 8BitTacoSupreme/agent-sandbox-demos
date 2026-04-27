#!/usr/bin/env bash
# Plain-shell demo: no environment manager at all.
# Whatever's installed via Homebrew (or apt, or system) is what we work with.
# This is the fallback for "I haven't adopted any of those tools" — and
# it's still better than running the agent against your unrestricted shell.

set -e

# Sanity check — these need to exist on PATH for agent-sbx to find them.
need=(bash cat ls grep sed awk find git jq curl python3)
missing=()
for tool in "${need[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Install these first (try: brew install ${missing[*]}):"
  printf '  - %s\n' "${missing[@]}"
  exit 1
fi

# Run agent-sbx prepare against the current PATH.
../../agent-sbx/agent-sbx prepare

echo
echo "Sandbox prepared. Next steps:"
echo "  ../../agent-sbx/agent-sbx elevate    # add kernel enforcement"
echo "  # or run a single command:"
echo "  ../../agent-sbx/agent-sbx -- bash    # interactive shell, fully sandboxed"
