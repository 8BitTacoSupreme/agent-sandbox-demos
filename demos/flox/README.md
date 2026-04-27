# flox demo — see sandflox

Flox has a fully-developed implementation of this pattern at:

> **https://github.com/flox/sandflox**

sandflox is a Go binary that wraps `flox activate` under Apple `sandbox-exec`,
enforcing what tools an agent can reach (shell enforcement) and what it can
mutate (kernel enforcement via SBPL).

## Quick start (build from source)

The sandflox binary is distributed as a Flox package. To build it locally:

```bash
git clone https://github.com/flox/sandflox.git
cd sandflox
flox build                    # builds the Go binary via the Flox manifest
flox activate                 # shell-tier enforcement immediate
sandflox elevate              # kernel-tier on top
```

## Zero-build alternative

If you don't want to compile Go, the `agent-sbx` tool in this repo provides the
same sandbox architecture as a single shell script:

```bash
cd demos/plain-shell          # or any other demo directory
../../sbx/agent-sbx prepare
../../sbx/agent-sbx elevate
```

## Why use sandflox over `agent-sbx` if you're on Flox

- Single Go binary, faster startup, fewer moving parts
- Embedded default policy — works without any config files
- Tested integration with Flox activation lifecycle
- Maintained by Flox

## Why use `agent-sbx` over sandflox

- You're not on Flox
- You want to read the implementation in shell
- You want to modify the policy generator yourself

The `requisites.txt` and `policy.toml` formats are compatible enough that
moving between the two is trivial.
