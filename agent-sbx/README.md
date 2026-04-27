# agent-sbx — environment-manager-agnostic sandbox

Single-file shell tool that turns any tool-managed dev environment into a
kernel-sandboxed agent workspace. Works downstream of Flox, devbox, mise,
asdf, direnv, or plain Homebrew/apt.

## How it works

`agent-sbx prepare` reads two files in the current directory:

- `requisites.txt` — list of binaries the agent is allowed to invoke
- `policy.toml` — workspace, network, denied paths, filesystem mode

For each binary in `requisites.txt`, `agent-sbx` runs `command -v` against
the **current PATH**. Whatever your environment manager set up determines
what gets resolved. The resolved absolute path is symlinked into
`.sandbox/bin/`. The unique parent directories of those binaries are added
to the kernel enforcement allowlist. The result is:

- A symlink farm at `.sandbox/bin/` containing exactly your allowlist
- On macOS: a Seatbelt profile at `.sandbox/profile.sb`
- On Linux: a bwrap args file at `.sandbox/bwrap.args`
- A function-armor file at `.sandbox/armor.bash` with shell-tier blockers
  for 26 package managers and Python escape vectors

`agent-sbx elevate` re-execs your shell under the platform kernel sandbox with
`PATH=.sandbox/bin` and the armor sourced.

## Why it works across env managers

Every modern env manager — Flox, devbox, mise, asdf, direnv-with-anything —
ends up doing the same thing at activation time: it puts a directory of
binaries on PATH. `agent-sbx` doesn't care what that directory is or how it got
there. It just resolves `command -v <name>` against the current PATH and
allowlists the result. This means the same `agent-sbx` invocation works whether
the binaries live in `/nix/store/...`, `~/.local/share/mise/installs/...`,
or `/opt/homebrew/bin/`.

The trust property changes — Nix-backed paths are input-addressed and
immutable, mise paths are versioned but mutable, Homebrew paths are mutable
— but the kernel boundary is the same.

## Platform support

### macOS

Uses `sandbox-exec` with a generated SBPL profile. Works on Apple Silicon
and Intel.

### Linux

Uses [bubblewrap](https://github.com/containers/bubblewrap) (bwrap) for
namespace isolation (PID, UTS, IPC, optionally network) and
[Landlock](https://landlock.io/) for kernel-level filesystem and network
access control.

**Graceful degradation**: `agent-sbx` probes for bwrap and Landlock at runtime
and uses whatever is available:

| bwrap | Landlock ABI | Result |
|-------|-------------|--------|
| yes | >= 4 (6.7+) | Full: bwrap namespaces + Landlock FS + Landlock network |
| yes | 1-3 (5.13-6.6) | bwrap namespaces + Landlock FS, no Landlock network |
| yes | 0 | bwrap-only: namespace isolation, no LSM |
| no | >= 1 | Landlock-only: LSM FS enforcement, no namespace isolation |
| no | 0 | Shell-only: PATH wipe + armor + requisites |

### sbx-landlock helper

Landlock requires syscalls that bash cannot invoke. `sbx-landlock` is a
small Go binary (zero external deps, build-tagged `linux`) that applies a
Landlock ruleset and execs the target command:

```bash
cd sbx/sbx-landlock
CGO_ENABLED=0 go build -o sbx-landlock .
# Place on PATH for sbx to find it
```

If `sbx-landlock` is not on PATH, `agent-sbx elevate` falls back to bwrap-only
enforcement.

## Inspiration

Heavily inspired by [sandflox](https://github.com/flox/sandflox), which
ships the same architecture as a Flox-native package. `agent-sbx` strips out the
Flox-specific assumptions to work with any env manager.
