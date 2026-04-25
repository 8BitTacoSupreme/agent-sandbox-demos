# Cloud dev demo — Codespaces / Gitpod

Run a sandboxed agent workspace in GitHub Codespaces or Gitpod using the
devcontainer spec.

## GitHub Codespaces

1. Fork this repo
2. Click **Code → Codespaces → New codespace**
3. Codespaces will build from `.devcontainer/devcontainer.json`
4. Once the terminal is ready:

```bash
sbx elevate    # enter the sandbox
```

## Gitpod

1. Prefix the repo URL with `gitpod.io/#`:
   ```
   https://gitpod.io/#https://github.com/your-fork/agent-sandbox-demos
   ```
2. Gitpod builds the devcontainer image automatically
3. Run `sbx prepare && sbx elevate` in the terminal

## What happens

- The devcontainer builds a Wolfi-based image with bash, coreutils, git,
  jq, python3, and bubblewrap
- `postCreateCommand` runs `sbx prepare` to bake the symlink farm and
  armor scripts
- You run `sbx elevate` to enter the bwrap + Landlock sandbox

## Verify

```bash
# Inside the sandbox:
bash tests/verify.sh
```

## Limitations

- **Codespaces**: The VM kernel determines Landlock ABI availability.
  As of 2026, Codespaces runs Ubuntu 22.04+ with kernel 5.15+, so
  Landlock FS enforcement works. Network enforcement (ABI v4) requires
  kernel 6.7+.
- **Gitpod**: Similar kernel constraints. Workspace pods run with
  limited capabilities; bwrap may need `--userns=keep-id`.
- **seccomp**: The devcontainer runs with `seccomp=unconfined` to allow
  bwrap's namespace syscalls. In production, use the explicit seccomp
  profile from `demos/container/`.
