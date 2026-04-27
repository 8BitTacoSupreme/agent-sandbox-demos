# VS Code Extension Bypass PoC

Minimal VS Code extension proving that `vscode.workspace.fs` bypasses
terminal-level sandboxing entirely.

## What this proves

Terminal sandboxing (agent-sbx, sandflox, any sandbox-exec / bwrap wrapper)
only controls code paths that go through the shell. VS Code extensions run
in the **extension host** — a separate Node.js process with full access to:

- `vscode.workspace.fs` — read/write workspace files
- `child_process` — spawn arbitrary processes
- `net` / `http` — make network connections
- Node.js `fs` — direct filesystem access

This extension registers a single command that writes a proof file via the
workspace API. No shell command is executed. No PATH is consulted. No
sandbox-exec / bwrap rule is evaluated.

## How to run

1. Open this directory in VS Code:

   ```bash
   code poc/extension-bypass/
   ```

2. Install dependencies and compile:

   ```bash
   npm install
   npm run compile
   ```

3. Press **F5** to launch the Extension Development Host

4. Open the command palette (`Cmd+Shift+P`) and run:

   > Extension Bypass: Write File

5. Check the workspace root — `EXTENSION_BYPASS_PROOF.txt` appears,
   written entirely through the VS Code API

## Why this matters

If your threat model includes "AI agent exfiltrates code" or "AI agent
writes files outside the workspace," terminal sandboxing is necessary but
not sufficient. An extension (or an AI agent with extension API access)
can bypass every terminal-level control.

### What would fix this

1. **Remote workspaces** (Coder, Codespaces, Gitpod): the kernel enforces
   on the remote host regardless of which code path initiated the I/O.
   See [`demos/coder/`](../../demos/coder/).

2. **VS Code extension sandboxing**: not currently implemented. Extensions
   run with the same privileges as the editor. There is no permission model
   for `workspace.fs`, `child_process`, or network access.

3. **Extension allowlisting**: manually restrict which extensions are installed.
   Operational control, not technical enforcement.

The kernel boundary works. But only if all code paths go through it.
