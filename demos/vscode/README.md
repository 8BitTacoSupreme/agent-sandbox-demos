# VS Code / Cursor demo — sandboxed terminal profile

Makes VS Code's (or Cursor's) integrated terminal launch into a sandboxed shell
automatically. Every new terminal panel runs through `activate.sh`, which calls
`agent-sbx prepare` and `agent-sbx elevate`.

## Prerequisites

- macOS or Linux
- VS Code or Cursor
- The binaries listed in `requisites.txt` available on your PATH

## Setup

### Option A: Open this directory directly

```bash
code demos/vscode/
# or
cursor demos/vscode/
```

The `.vscode/settings.json` is picked up automatically. Open a new terminal
(`Ctrl+`` `) — it launches the Sandboxed profile.

### Option B: Copy settings into your project

Copy `.vscode/settings.json` and `activate.sh` into your own project. Adjust
the `activate.sh` path in settings.json to match your layout.

## How it works

1. `.vscode/settings.json` defines a "Sandboxed" terminal profile for macOS and Linux
2. The profile runs `activate.sh` via bash
3. `activate.sh` resolves `SCRIPT_DIR`, finds `agent-sbx` relative to the repo root
4. Runs `agent-sbx prepare` (builds symlink farm, generates armor)
5. `exec agent-sbx elevate` (re-execs under sandbox-exec / bwrap)

The terminal is now sandboxed: PATH-restricted, function-armored, kernel-enforced.

## Verify the sandbox

```bash
# From inside the sandboxed terminal:
../../tests/verify.sh
```

## Works with Cursor

Cursor uses the same settings format as VS Code. The `.vscode/settings.json`
file works identically in both editors.

## Critical limitation: extensions bypass terminal sandboxing

The terminal sandbox protects against escape via shell commands. **It does not
protect against VS Code extensions.**

Extensions run in the Node.js extension host process, which has full access to:

- `vscode.workspace.fs` — read/write any file in the workspace
- `child_process` — spawn processes outside the terminal
- `net` / `http` — make network connections
- `fs` (Node.js) — direct filesystem access

None of these go through the integrated terminal. A malicious or compromised
extension can write files, exfiltrate data, or spawn processes completely outside
the terminal sandbox boundary.

### Proof of concept

See [`poc/extension-bypass/`](../../poc/extension-bypass/) for a minimal VS Code
extension that demonstrates this gap — it writes a file via `workspace.fs` while
the terminal sandbox is active.

### What would fix this

- **Remote workspaces** (Coder, Codespaces, Gitpod): move the entire environment
  to a host where the kernel enforces regardless of code path. See
  [`demos/coder/`](../coder/).
- **VS Code extension sandboxing**: not currently supported by VS Code. Extensions
  run with the same privileges as the editor itself.
- **Extension allowlisting**: manually audit and restrict which extensions are
  installed. Operational, not technical.

The kernel boundary works. But only if all code paths go through it.
