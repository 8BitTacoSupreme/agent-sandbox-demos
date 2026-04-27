# plain-shell demo

No environment manager at all. You have Homebrew (or apt on Linux),
some tools installed, and you want to sandbox an agent without first
migrating to mise/devbox/Flox.

Trust property is the weakest of the demos — Homebrew binaries live at
mutable paths like `/opt/homebrew/bin/python3`. A locally-installed
malicious binary at the same path would still be allowlisted. But for
the "agent inside the sandbox" threat model, the kernel boundary still
holds: the agent can't write to `/opt/homebrew` from inside the sandbox.

This is the demo to read if you're convinced you don't need an env
manager but still want kernel-level isolation for AI agents.

## Prerequisites

- macOS
- Homebrew (or just system tools — anything in your existing PATH works)
- The binaries listed in `requisites.txt` available somewhere on PATH

## Run

```bash
# Resolve binaries against your current PATH and prepare the sandbox
./activate.sh

# Add kernel enforcement
../../agent-sbx/agent-sbx elevate

# Or run a one-shot sandboxed command
../../agent-sbx/agent-sbx -- bash
```

## Caveats

- No version pinning — `python3` is whatever your PATH gives you
- No reproducibility across machines — each developer's allowlist points
  at different absolute paths (`/opt/homebrew` on ARM Mac, `/usr/local`
  on Intel Mac, `/usr/bin` on Linux)
- This is fine for personal use, weaker for team standardization

If you want reproducible sandboxing across a team, look at the devbox or
direnv-nix demos instead.

## What you still get

Even with the weaker trust property, you still get:

- PATH-restricted shell (only allowlisted binaries reachable)
- Function armor blocking 26 package managers with parseable error messages
- Kernel-enforced denial of writes outside workspace, reads to credential paths, and all network
- Symlink/redirection bypass attempts caught at the syscall level

That's a meaningful improvement over running an agent against your raw shell,
even if the binaries themselves come from a less trustworthy source.
