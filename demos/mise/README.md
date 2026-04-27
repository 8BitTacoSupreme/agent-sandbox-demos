# mise demo

Mise manages per-project tool versions. It's not Nix-backed — binaries
live at `~/.local/share/mise/installs/<tool>/<version>/bin/`, which is
versioned but not input-addressed. The sandbox boundary still works,
but the trust property is weaker than the Nix-backed demos: a tampered
binary at the same install path would still be allowlisted.

For most threat models (agent inside the box trying to escape), this
doesn't matter — the agent can't write to `~/.local/share/mise/` any
more than it can write to `/nix/store`. For threats from parallel
processes outside the sandbox, Nix-backed env managers are stronger.

## Prerequisites

- macOS
- [mise](https://mise.jdx.dev) installed (`curl https://mise.run | sh`)

## Run

```bash
# Trust the project (mise security)
mise trust

# Activate — `enter` hook calls agent-sbx prepare automatically
cd .  # or `mise activate` if not auto-activating

# Add kernel enforcement
mise run elevate
# Or in one step:
mise run agent
```

## Important: shims must be disabled

Mise's default shim behavior — every binary in PATH points at the same
`mise` shim, which exec's the right version — defeats the sandbox
allowlist. The kernel only sees one binary (`mise`) and would have to
allow it to fork+exec arbitrarily, which is the opposite of what we want.

This demo sets `shims = false` so PATH points directly at install dirs.
That's the configuration to use whenever you're combining mise with a
sandbox.

## What's blocked / allowed

Same as the devbox demo — see `../devbox/README.md` for the full table.
The shell-tier function armor blocks the same 26 package managers; the
kernel-tier SBPL blocks the same writes, denied paths, and network.
