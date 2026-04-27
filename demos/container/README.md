# Container demo — Docker / Podman

Run a sandboxed AI agent shell inside a container with seven layers of
defense-in-depth.

## Defense-in-depth layers

| # | Layer | What it does |
|---|-------|-------------|
| 1 | **seccomp** | Syscall allowlist — blocks ptrace, kexec, module loading |
| 2 | **Read-only rootfs** | Container root is immutable; writes go to tmpfs or workspace volume |
| 3 | **Non-root user** | Agent runs as uid 1000, not root |
| 4 | **Dropped capabilities** | Only `SYS_ADMIN` retained (bwrap needs it); everything else dropped |
| 5 | **bwrap namespaces** | PID, UTS, IPC isolation inside the container |
| 6 | **Landlock LSM** | Kernel-level filesystem access control (kernel 5.13+) |
| 7 | **agent-sbx shell tier** | PATH wipe + symlink farm + function armor for 26 package managers |

## Prerequisites

- Docker 20.10+ or Podman 4.0+
- Linux host with kernel 5.13+ (for Landlock; works without, just fewer layers)

## Quick start

```bash
# Build and run
docker compose up --build

# Or manually:
docker build -t agent-sbx -f Dockerfile ../..
docker run --rm -it \
  --security-opt seccomp=seccomp-profile.json \
  --cap-add SYS_ADMIN \
  --cap-drop ALL \
  --read-only \
  --tmpfs /tmp:size=100M \
  agent-sbx
```

## Verify the sandbox

```bash
# From inside the container:
bash tests/verify.sh
```

## Podman rootless

Podman runs rootless by default. The same image works:

```bash
podman build -t agent-sbx -f Dockerfile ../..
podman run --rm -it \
  --security-opt seccomp=seccomp-profile.json \
  --cap-add SYS_ADMIN \
  --cap-drop ALL \
  --read-only \
  --tmpfs /tmp:size=100M \
  agent-sbx
```

Note: rootless Podman uses user namespaces automatically, adding another
isolation layer. bwrap inside the container may require `--userns=keep-id`
depending on your Podman version.

## Platform notes

- **x86_64**: Primary target. All layers work on kernel 5.13+.
- **aarch64**: Works on ARM Linux hosts (Graviton, Ampere). Same kernel requirements.
- **macOS Docker Desktop**: bwrap won't work inside the Linux VM's default
  kernel config. Shell-tier enforcement still active.
- **Landlock network** (kernel 6.7+): If your kernel supports ABI v4,
  `agent-sbx-landlock` will also enforce TCP connect/bind restrictions.
