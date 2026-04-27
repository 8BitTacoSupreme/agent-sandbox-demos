#!/usr/bin/env bash
# asdf demo: structurally identical to mise.
#
# asdf installs to ~/.asdf/installs/<plugin>/<version>/bin/<binary>
# Versioned but not input-addressed — same trust property as mise.

set -e

# Make sure asdf has the tools from .tool-versions installed
asdf install || { echo "asdf install failed"; exit 1; }

# asdf doesn't have a `shims=false` mode — its shims always intercept.
# To get a meaningful sandbox allowlist, we point at the install dirs
# directly via PATH manipulation rather than going through asdf's shims.
ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
ASDF_BINS=()
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  plugin="${line%% *}"
  version="${line##* }"
  d="$ASDF_DATA_DIR/installs/$plugin/$version/bin"
  [[ -d "$d" ]] && ASDF_BINS+=("$d")
done < .tool-versions

# Prepend the real install dirs to PATH so agent-sbx prepare resolves correctly
NEW_PATH="$(IFS=:; echo "${ASDF_BINS[*]}"):$PATH"
export PATH="$NEW_PATH"

# Now the same flow as the other demos
../../sbx/agent-sbx prepare

echo
echo "Sandbox prepared. Next steps:"
echo "  ../../sbx/agent-sbx elevate"
echo "  # or in one step:"
echo "  ../../sbx/agent-sbx -- bash"
