# sbx — environment-manager-agnostic sandbox

Single-file shell tool that turns any tool-managed dev environment into a
kernel-sandboxed agent workspace. Works downstream of Flox, devbox, mise,
asdf, direnv, or plain Homebrew.

## How it works

`sbx prepare` reads two files in the current directory:

- `requisites.txt` — list of binaries the agent is allowed to invoke
- `policy.toml` — workspace, network, denied paths, filesystem mode

For each binary in `requisites.txt`, `sbx` runs `command -v` against
the **current PATH**. Whatever your environment manager set up determines
what gets resolved. The resolved absolute path is symlinked into
`.sandbox/bin/`. The unique parent directories of those binaries are added
to the SBPL `(allow file-read*)` allowlist. The result is:

- A symlink farm at `.sandbox/bin/` containing exactly your allowlist
- A Seatbelt profile at `.sandbox/profile.sb` that allows reads from
  the binaries' parent directories, writes to your workspace + /tmp,
  and denies network + credential paths
- A function-armor file at `.sandbox/armor.bash` with shell-tier blockers
  for 26 package managers and Python escape vectors

`sbx elevate` re-execs your shell under `sandbox-exec -f .sandbox/profile.sb`
with `PATH=.sandbox/bin` and the armor sourced.

## Why it works across env managers

Every modern env manager — Flox, devbox, mise, asdf, direnv-with-anything —
ends up doing the same thing at activation time: it puts a directory of
binaries on PATH. `sbx` doesn't care what that directory is or how it got
there. It just resolves `command -v <name>` against the current PATH and
allowlists the result. This means the same `sbx` invocation works whether
the binaries live in `/nix/store/...`, `~/.local/share/mise/installs/...`,
or `/opt/homebrew/bin/`.

The trust property changes — Nix-backed paths are input-addressed and
immutable, mise paths are versioned but mutable, Homebrew paths are mutable
— but the kernel boundary is the same.

## Linux

This implementation is macOS-only (uses `sandbox-exec` / SBPL). The Linux
equivalent swaps the SBPL profile generator for a `bwrap` invocation
builder + a Landlock policy. Same `requisites.txt`, same `policy.toml`,
different backend. A `sbx-linux` companion script is left as an exercise
(see TODO at the bottom of `sbx`).

## Inspiration

Heavily inspired by [sandflox](https://github.com/flox/sandflox), which
ships the same architecture as a Flox-native package. `sbx` strips out the
Flox-specific assumptions to work with any env manager.
