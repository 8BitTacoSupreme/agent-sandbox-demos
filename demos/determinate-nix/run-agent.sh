#!/usr/bin/env bash
# Non-direnv path: enter the dev shell and immediately re-exec under sandbox-exec.
# Use this if you don't have direnv installed.
set -e

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This demo's elevate step is macOS-only (sandbox-exec)."
  echo "Linux users: enter the shell with 'nix develop' and use bwrap manually."
  exit 1
fi

# nix develop runs the shellHook (which calls sbx prepare), then we re-exec
# the whole thing under sandbox-exec for kernel enforcement.
exec nix develop --command bash -c '
  ../../sbx/sbx prepare
  exec ../../sbx/sbx elevate
'
