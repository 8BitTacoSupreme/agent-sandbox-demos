# agent-sandbox-demos — Context for Blog Post

## What This Repo Is

A collection of working demos that apply **kernel-level sandboxing** to AI
coding agents across every major dev environment manager (Flox, devbox, mise,
asdf, direnv+nix, plain shell) plus containers, Kubernetes, and cloud dev
environments (Codespaces/Gitpod).

**Repo:** `github.com/8BitTacoSupreme/agent-sandbox-demos`
**Branch:** `main`
**Key tool:** `agent-sbx/agent-sbx` — single bash script (~790 lines)

## The Core Argument

AI agents escape prompt-level constraints trivially (write a Python script,
run it via bash, bypass the "don't write outside workspace" instruction). The
internet says "just use Docker." That's the wrong answer — Docker adds a
daemon, image pipeline, layered FS driver, and inherited CVE surface to solve
a problem the OS already solves natively.

macOS has `sandbox-exec` (Seatbelt/SBPL). Linux has `bwrap` (bubblewrap) +
`Landlock` (kernel LSM). Same `requisites.txt`, same `policy.toml`, different
kernel backend. No daemon, no image layer, no VM.

## How agent-sbx Works

Two enforcement tiers, both independent:

**Shell tier** (immediate, parseable by agents):
1. PATH wipe — only `.sandbox/bin/` on PATH
2. Symlink farm — each requisite resolved to absolute path, symlinked
3. Function armor — 26 package managers return exit 126 with `[agent-sbx] BLOCKED:` messages

**Kernel tier** (catches shell bypasses):
- macOS: `sandbox-exec -f .sandbox/profile.sb` (SBPL deny-default)
- Linux: `bwrap` (PID/UTS/IPC/net namespaces) + `agent-sbx-landlock` (Go helper for Landlock LSM syscalls)

## Two Config Files Drive Everything

**`requisites.txt`** — one binary name per line. The agent's allowlist.

**`policy.toml`** — declares network mode (blocked/unrestricted), filesystem
mode (workspace/strict/permissive), denied credential paths (~/.ssh, ~/.aws, etc.).

## Directory Structure

```
agent-sbx/
  agent-sbx              # main bash script (790 lines)
  agent-sbx-landlock/    # Go helper for Landlock syscalls (436 lines, linux-only)
  README.md
demos/
  plain-shell/           # no env manager, just Homebrew/apt
  flox/                  # pointer to sandflox (Flox-native)
  devbox/                # Nix-backed, devbox.json
  determinate-nix/       # modern flakes
  direnv-nix/            # direnv + shell.nix
  mise/                  # versioned tools (shims=false required)
  asdf/                  # same shape as mise
  container/             # Docker/Podman + seccomp + bwrap + Landlock
  kubernetes/            # K8s deployment + NetworkPolicy + seccomp
  cloud-dev/             # Codespaces/Gitpod devcontainer
  coder/                 # Coder workspace template (Docker + Terraform)
  vscode/                # VS Code / Cursor terminal profile
poc/
  extension-bypass/      # VS Code extension proving workspace.fs bypasses terminal sandbox
tests/
  verify.sh              # 19 block tests + 7 allow tests
  run-all.sh             # runs every demo whose env manager is installed
```

## Platform Matrix

| Platform | Kernel Backend | FS Enforcement | Network |
|----------|---------------|----------------|---------|
| macOS | sandbox-exec (SBPL) | Seatbelt | Seatbelt |
| Linux 6.7+ | bwrap + Landlock v4 | Landlock | Landlock |
| Linux 5.13–6.6 | bwrap + Landlock v1-3 | Landlock | bwrap only |
| Linux < 5.13 | bwrap only | Namespaces | bwrap only |
| Any (fallback) | Shell-only | PATH + armor | None |

`agent-sbx` probes at runtime and uses whatever's available. Graceful degradation.

## Trust Properties (What Changes Per Row)

- **Strong** (Flox, devbox, Nix-backed): binaries at `/nix/store/<hash>/` — immutable, input-addressed
- **Medium** (mise, asdf): versioned but mutable paths
- **Weak** (plain shell): whatever's on PATH, mutable

For the "agent tries to escape" threat model, all rows are equivalent — the
kernel boundary holds. Trust differences matter for supply-chain scenarios.

## Defense-in-Depth (Container/K8s)

Nine layers when running in containers or Kubernetes:

1. seccomp profile (syscall allowlist)
2. bwrap namespaces (PID, UTS, IPC, net)
3. Landlock LSM (filesystem + network)
4. Seatbelt/bwrap credential masking (~/.ssh → /dev/null)
5. PATH isolation (symlink farm)
6. Function armor (26 package managers blocked)
7. Read-only root filesystem
8. Non-root user (uid 1000)
9. K8s NetworkPolicy + Pod SecurityContext + resource limits

## Key Design Decisions

- **No external dependencies** in agent-sbx — pure bash + coreutils
- **agent-sbx-landlock** exists because Landlock requires syscalls bash can't invoke (Go, zero deps, build-tagged linux)
- **Named agent-sbx** (not sbx) to avoid collision with Docker's `sbx` CLI which is in the same problem space
- **Inspired by sandflox** (github.com/flox/sandflox) — portable reimplementation that works with any env manager

## Blog Post Angles

1. **"The OS already solved agent sandboxing"** — sandbox-exec and bwrap+Landlock existed before agents. Docker is overkill for this threat model.
2. **The matrix** — same policy file, same allowlist, seven different env managers, one kernel boundary. What changes is the wiring, not the security.
3. **Defense-in-depth** — shell tier catches the 90% case (agent calls `pip install`). Kernel tier catches the bypass (`bash -c 'echo pwned > /etc/passwd'`). Container/K8s adds more layers.
4. **Graceful degradation** — works on any Linux kernel, just with fewer enforcement layers. No hard requirement on bleeding-edge features.
5. **The trust spectrum** — Nix store paths are immutable; Homebrew paths aren't. The kernel boundary is the same, but the supply-chain story differs.

## Verification

`tests/verify.sh` tries 19 escape vectors (pip install, write to /etc, read ~/.ssh, curl, python -m pip, etc.) and 7 normal operations (workspace writes, git status, arithmetic). All blocks blocked + all allows allowed = pass.

## Part 3 — IDE and Extension Layer

### Hook

Parts 1 and 2 covered terminal sandboxing: the OS-native kernel boundary
(sandbox-exec, bwrap+Landlock) and the env-manager matrix. Part 3 targets
the next attack surface: **the IDE itself**.

### The solved case: VS Code / Cursor terminal profiles

`demos/vscode/` wires a "Sandboxed" terminal profile into VS Code (or Cursor).
Every new terminal panel auto-launches through `activate.sh`, which calls
`agent-sbx prepare` + `agent-sbx elevate`. The integrated terminal is now
PATH-restricted, function-armored, and kernel-enforced.

### The gap: extensions

VS Code extensions run in the **extension host** — a Node.js process with
full access to `vscode.workspace.fs`, `child_process`, `net`, and Node's `fs`.
None of these go through the terminal. A 30-line extension can write files,
spawn processes, or make network connections completely outside the terminal
sandbox.

`poc/extension-bypass/` proves this: register one command, call
`workspace.fs.writeFile`, and a proof file appears in the workspace root.
No shell, no PATH, no sandbox-exec rule evaluated.

### The architectural answer: remote workspaces

Coder, Codespaces, and Gitpod move the entire environment to a remote host.
Every code path — terminal, extension API, language server, debug adapter —
runs inside the kernel boundary. The sandbox isn't the terminal; it's the
machine.

`demos/coder/` provides a Terraform template that provisions a Docker-based
Coder workspace with agent-sbx baked in and kernel enforcement via bwrap.

### Blog angles (Part 3)

1. **"Your terminal sandbox doesn't protect against extensions"** — the
   extension host is a separate process with full Node.js privileges
2. **The PoC** — 30 lines of TypeScript, one `workspace.fs.writeFile` call,
   and your sandbox is irrelevant
3. **Remote workspaces as the fix** — move the machine boundary to cover
   all code paths, not just the terminal
4. **The composability argument** — terminal sandbox for terminal escapes,
   remote workspace for extension escapes, they're complementary

### LinkedIn Post Draft (Part 3)

Parts 1 and 2 covered the terminal. The kernel boundary works — sandbox-exec on macOS, bwrap+Landlock on Linux. Same policy file, same allowlist, ten different environment managers. The agent can't escape via shell commands.

But the terminal isn't the only attack surface.

VS Code and Cursor run extensions in a Node.js process called the extension host. That process has full access to vscode.workspace.fs, child_process, net, and Node's fs module. None of it goes through the integrated terminal.

I wrote a 30-line VS Code extension to prove it. One command: workspace.fs.writeFile. A proof file appears in the workspace root. The terminal sandbox is active. The sandbox-exec rules are enforced. And the extension writes the file anyway — because it never touched the terminal.

This isn't a vulnerability in agent-sbx or sandflox. It's an architectural gap in VS Code. Extensions run with the same privileges as the editor itself. There's no permission model for filesystem access, no sandbox for the extension host, no way to restrict what an extension can do once installed.

The terminal sandbox is still necessary. It blocks the 90% case: agent calls pip install, tries to write /etc/passwd via shell redirect, spawns curl to exfiltrate. But the 10% case — extension API, language server protocol, debug adapter — goes around it entirely.

The fix is architectural: move the environment to a remote host where the kernel enforces regardless of code path. Coder, Codespaces, Gitpod. Every write — terminal, extension, language server — hits the same kernel boundary. The sandbox isn't the terminal. It's the machine.

I built demos for both sides. demos/vscode/ wires a sandboxed terminal profile for VS Code and Cursor. poc/extension-bypass/ proves the gap. demos/coder/ shows the Coder workspace template that closes it.

The kernel boundary works. But only if all code paths go through it.

Repo: github.com/flox/agent-sandbox-demos

## Commits

```
e829a07 refactor: rename sbx → agent-sbx to avoid Docker sbx collision
a8404a6 feat: Linux container runtime — bwrap + Landlock + K8s + cloud-dev
63cb8e3 docs: replace matrix.svg with matrix-preview.png
ad8048d feat: agent-sandbox-demos v0.1.0
```
