# agent-sandbox-demos

Working demos showing how to apply kernel-level sandboxing to AI coding agents
across every major dev environment manager: **Flox**, **devbox**, **mise**,
**asdf**, **direnv + nix-shell**, and **plain Homebrew/system shell** — plus
**containers**, **Kubernetes**, and **cloud dev environments**.

The pitch: **the OS solved this**. Whichever environment manager you use,
the sandbox boundary is the same — `sandbox-exec` on macOS, `bwrap + Landlock`
on Linux. What changes between rows is the wiring, not the boundary.

![matrix](matrix-preview.png)

## TL;DR

```bash
git clone <this-repo>
cd agent-sandbox-demos/demos/<your-env-manager>
# follow the README in that directory
```

Each demo:

- Defines its tool set in the env-manager-native config (devbox.json,
  mise.toml, .envrc + shell.nix, etc.)
- Shares the same `requisites.txt` (the agent's allowlist) and `policy.toml`
  (workspace, network, denied paths)
- Wires up the `agent-sbx` tool to generate `.sandbox/{bin,profile.sb,armor.bash}`
  on activation
- Provides a one-command path to launch a sandboxed agent shell

## Why this exists

A screenshot made the rounds. An AI agent was told not to write outside its
workspace. It agreed. Then wrote a Python script and ran it via bash to
modify the file anyway. The internet's response: "Just use Docker."

That's the wrong answer. Not because Docker doesn't work — it would have
blocked that specific bypass — but because it adds a daemon, an image
pipeline, a layered filesystem driver, and an inherited CVE surface
(CVE-2019-5736, CVE-2024-21626) to solve a problem the OS already solves
natively.

This repo shows what the OS-native answer looks like, regardless of which
tool you're using to manage your dev environment.

## What's in each demo

```
demos/<env-manager>/
├── requisites.txt    Allowlisted binaries (one per line)
├── policy.toml       Workspace, network, denied paths, fs mode
├── README.md         Specific instructions for this env manager
└── <env-config>      devbox.json | mise.toml | .envrc + shell.nix | etc.
```

The shared `agent-sbx/agent-sbx` tool (single shell script, ~600 lines) does the
common work:

1. Read `requisites.txt`
2. For each binary, run `command -v` against current PATH
3. Symlink resolved absolute paths into `.sandbox/bin/`
4. Generate `.sandbox/profile.sb` (Seatbelt SBPL) on macOS, `.sandbox/bwrap.args` on Linux
5. Generate `.sandbox/armor.bash` (function armor for 26 package managers)
6. Provide `elevate` to re-exec under `sandbox-exec` (macOS) or `bwrap` + Landlock (Linux)

## Two enforcement tiers

**Shell tier** (PATH wipe + symlink farm + function armor) is active as
soon as the env manager activates. It's parseable: blocked actions return
`[agent-sbx] BLOCKED: <reason>` so agents can adapt.

**Kernel tier** (sandbox-exec / SBPL on macOS, bwrap + Landlock on Linux)
is active after `agent-sbx elevate`. It catches what the shell tier can't: bash
redirections (`> /etc/passwd`), absolute-path binary invocations, anything
that bypasses your shell.

Both tiers work independently; combined they're defense in depth.

## Platform matrix

`agent-sbx` auto-detects the platform and dispatches to the right kernel backend:

| Platform | Kernel Backend | Namespaces | FS LSM | Network | Notes |
|----------|---------------|------------|--------|---------|-------|
| **macOS** | sandbox-exec (SBPL) | N/A | Seatbelt | Seatbelt | Apple Silicon + Intel |
| **Linux 6.7+** | bwrap + Landlock | PID, UTS, IPC, net | Landlock v4 | Landlock v4 | Full enforcement |
| **Linux 5.13–6.6** | bwrap + Landlock | PID, UTS, IPC, net | Landlock v1-3 | bwrap only | No Landlock network |
| **Linux < 5.13** | bwrap only | PID, UTS, IPC, net | None | bwrap only | No Landlock |
| **Linux (no bwrap)** | Landlock only | None | Landlock | Landlock (v4+) | No namespace isolation |
| **Any (fallback)** | Shell-only | None | None | None | PATH + armor + requisites |

## Linux — bwrap + Landlock

On Linux, `agent-sbx elevate` uses [bubblewrap](https://github.com/containers/bubblewrap)
for namespace isolation and [Landlock](https://landlock.io/) for kernel-level
filesystem (and on 6.7+, network) access control.

### How it works

1. **bwrap** creates PID, UTS, IPC namespaces (and optionally net). It
   bind-mounts system paths read-only, the workspace read-write, and
   `/dev/null` over credential paths (`.ssh`, `.aws`, `.gnupg`).
2. **agent-sbx-landlock** (a small Go helper) applies a Landlock ruleset before
   exec'ing the shell. Landlock rules are additive — anything without an
   explicit rule gets denied. This catches symlink traversal, `/proc` escapes,
   and any path not in the allowlist.
3. **Shell tier** (same as macOS) provides function armor, requisites
   filtering, and PATH isolation.

### Graceful degradation

`agent-sbx` probes for bwrap and Landlock at runtime and uses whatever's available:

| bwrap | Landlock ABI | Result |
|-------|-------------|--------|
| yes | >= 4 (6.7+) | Full: bwrap namespaces + Landlock FS + Landlock network |
| yes | 1-3 (5.13-6.6) | bwrap namespaces + Landlock FS, no Landlock network |
| yes | 0 | bwrap-only: namespace isolation, no LSM |
| no | >= 1 | Landlock-only: LSM FS enforcement, no namespace isolation |
| no | 0 | Shell-only: PATH wipe + armor + requisites |

### agent-sbx-landlock

Landlock requires `landlock_create_ruleset` / `landlock_add_rule` /
`landlock_restrict_self` syscalls that bash cannot invoke. `agent-sbx-landlock` is
a zero-dependency Go binary (build-tagged `linux`) that applies the ruleset
and execs the target command. Build it with:

```bash
cd agent-sbx/agent-sbx-landlock
CGO_ENABLED=0 go build -o agent-sbx-landlock .
```

If `agent-sbx-landlock` is not on PATH, `agent-sbx elevate` falls back to bwrap-only
enforcement and logs a warning.

## Trust properties (what changes per row)

| Trust | Env Managers | Why |
|-------|--------------|-----|
| **Strong** | Flox, devbox, Determinate Nix, direnv+nix-shell | Binaries live at `/nix/store/<hash>/bin/<n>` — input-addressed[^ia] and immutable. A tampered binary has a different hash and a different path; the allowlist won't match. |
| **Medium** | mise, asdf | Binaries live at `~/.local/share/mise/installs/<tool>/<version>/bin/<n>` — versioned but mutable. A user-writable path on disk is not protected against local tampering the way the read-only Nix store is. |
| **Weak** | direnv (bare), plain shell | Binaries come from whatever's on PATH. `/opt/homebrew/bin/python3` is mutable; the allowlist is "trust the path, not the bytes." |

[^ia]: Standard Nix store paths are *input-addressed* — the store path hash is derived from the build inputs (source, dependencies, flags), not the output bytes. This is still a strong integrity property: the same inputs always produce the same path, and paths are read-only once built. *Content-addressed derivations* (where the hash is the output hash) are an opt-in experimental feature (`__contentAddressed = true`) and not the default.

For the "agent inside the sandbox tries to escape" threat model, all three
tiers are roughly equivalent — the kernel boundary holds regardless of
where the binaries came from. Trust differences matter for "parallel
process tampered with the binary" or "binary supply-chain attack" scenarios,
where the Nix-backed options give you more.

## Defense-in-depth (container / K8s deployments)

When running in containers or Kubernetes, agent-sbx layers on top of the
platform's own isolation:

| # | Layer | macOS (local) | Linux (container/K8s) |
|---|-------|--------------|----------------------|
| 1 | **Syscall filter** | Seatbelt (SBPL deny default) | seccomp profile |
| 2 | **Namespace isolation** | N/A | bwrap (PID, UTS, IPC, net) |
| 3 | **FS access control** | Seatbelt file-read/write rules | Landlock LSM |
| 4 | **Network control** | Seatbelt network rules | Landlock net (6.7+) / bwrap --unshare-net / NetworkPolicy |
| 5 | **Credential masking** | Seatbelt deny on ~/.ssh etc. | bwrap binds /dev/null over paths |
| 6 | **PATH isolation** | Symlink farm in .sandbox/bin/ | Same |
| 7 | **Function armor** | Shell functions return 126 | Same |
| 8 | **Container hardening** | N/A | Read-only rootfs, non-root user, dropped caps |
| 9 | **K8s policies** | N/A | NetworkPolicy, Pod SecurityContext, resource limits |

## Inspiration

The architecture is heavily inspired by [sandflox](https://github.com/flox/sandflox),
which ships this pattern as a Flox-native package. `agent-sbx` is essentially a
portable shell-script reimplementation of sandflox's core, designed to
work downstream of any environment manager. The Flox demo in this repo
points at sandflox directly — if you're already on Flox, use that.

## Running a demo

Pick your environment and follow its README:

### Local (env manager)

- [demos/flox/](demos/flox/) — pointer to sandflox (Flox users go there)
- [demos/devbox/](demos/devbox/) — Nix-backed, JSON config
- [demos/determinate-nix/](demos/determinate-nix/) — modern flakes (Determinate, upstream Nix, nix-darwin)
- [demos/direnv-nix/](demos/direnv-nix/) — direnv + legacy `shell.nix`
- [demos/mise/](demos/mise/) — versioned tools, `shims=false` required
- [demos/asdf/](demos/asdf/) — same shape as mise
- [demos/plain-shell/](demos/plain-shell/) — no env manager, just Homebrew

### Container / Cloud

- [demos/container/](demos/container/) — Docker / Podman with seccomp + bwrap + Landlock
- [demos/kubernetes/](demos/kubernetes/) — K8s deployment with NetworkPolicy + seccomp + defense-in-depth
- [demos/cloud-dev/](demos/cloud-dev/) — Codespaces / Gitpod devcontainer

Every demo ends with a sandboxed shell where you can launch an agent:

```bash
# inside the sandboxed shell
claude-code      # or your agent of choice
```

## Verification

Run `tests/verify.sh` from inside any sandboxed shell to confirm the boundary
is enforcing as expected. It tries 19 escape vectors (package installs,
filesystem writes outside workspace, credential reads, network connections,
Python `-m pip`, etc.) and 7 normal operations (workspace writes, git status,
arithmetic). Pass = all blocks blocked, all allows allowed.

## Caveats

- macOS Apple-Silicon tested; Intel macs should work but binary paths differ
  (`/usr/local/Homebrew` instead of `/opt/homebrew`).
- Linux requires bwrap and/or kernel 5.13+ for full enforcement. Shell-tier
  enforcement works everywhere.
- The function armor blocks 26 package managers by name. An agent that finds
  a 27th one we didn't list slips through the shell tier — but the kernel
  tier still blocks anything trying to write outside the workspace, so the
  practical attack surface is small.
- `requisites.txt` is a denylist by absence: anything not on the list isn't
  on PATH inside the sandbox. The kernel tier additionally blocks
  absolute-path invocations of binaries not in the read allowlist.

## License

MIT. Use it, fork it, ship it.
