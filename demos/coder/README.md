# Coder demo — remote workspace with agent-sbx

Provisions a Docker-based [Coder](https://coder.com) workspace with agent-sbx
baked into the image. The Coder agent's startup script runs `agent-sbx prepare`
so the sandbox is ready before any agent command runs.

This is the architectural answer to extension-level bypass attacks: move the
entire environment to a remote host where the kernel enforces regardless of
which code path (terminal, extension API, child_process) initiated the write.

## Defense-in-depth layers

| # | Layer | What it does |
|---|-------|-------------|
| 1 | **Read-only rootfs** | Container root is immutable; writes go to tmpfs or workspace volume |
| 2 | **Non-root user** | Agent runs as uid 1000, not root |
| 3 | **Dropped capabilities** | Only `SYS_ADMIN` retained (bwrap needs it); everything else dropped |
| 4 | **bwrap namespaces** | PID, UTS, IPC isolation inside the container |
| 5 | **agent-sbx shell tier** | PATH wipe + symlink farm + function armor for 26 package managers |

## Prerequisites

- [Coder](https://coder.com/docs/install) server running (local or remote)
- Docker available on the Coder host
- `coder` CLI authenticated (`coder login`)

## Quick start

```bash
# Push the template to your Coder deployment
coder template push sandbox-agent -d demos/coder

# Create a workspace from the template
coder create sandbox-test --template sandbox-agent

# Connect
coder ssh sandbox-test
```

## Verify the sandbox

```bash
# From inside the Coder workspace:
agent-sbx elevate
bash tests/verify.sh
```

## How it works

1. `main.tf` defines a Docker-based Coder workspace with security hardening
   (read-only root, dropped caps, tmpfs scratch, non-root user)
2. The image includes `agent-sbx` and the policy/requisites files
3. The Coder agent's `startup_script` runs `agent-sbx prepare` on workspace start
4. `agent-sbx elevate` adds kernel-tier enforcement (bwrap namespaces)

## Why Coder (or Codespaces/Gitpod) matters for Part 3

Terminal sandboxing protects against escape via shell commands. But VS Code
extensions run in the Node.js extension host process with full access to
`vscode.workspace.fs`, `child_process`, and `net` — none of which go through
the terminal.

Remote workspaces solve this architecturally: every code path (terminal, extension
API, language server, debug adapter) runs on the remote host where the kernel
enforces filesystem, network, and process isolation. The sandbox boundary isn't
the terminal — it's the machine.

## Caveats

- This is a demo template, not production Terraform. No variables.tf, no state backend.
- bwrap inside Docker requires `SYS_ADMIN` capability.
- Landlock (kernel 5.13+) is not configured in this demo; add `agent-sbx-landlock`
  for full Linux defense-in-depth (see the container demo).
