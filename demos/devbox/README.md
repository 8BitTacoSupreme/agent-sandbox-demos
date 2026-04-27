# devbox demo

Devbox is Nix-backed — every binary lives at a deterministic
`/nix/store/<hash>/bin/<n>` path. This is the same trust property
Flox provides. The sandbox allowlist points at input-addressed paths,
so allowlisted binaries can't be tampered with without changing their
path (which would invalidate the allowlist).

## Prerequisites

- macOS
- [devbox](https://www.jetify.com/devbox) installed (`curl -fsSL https://get.jetify.com/devbox | bash`)
- Nix installed (devbox bootstraps this for you on first run)

## Run

```bash
# Enter the devbox shell — agent-sbx prepare runs automatically via init_hook
devbox shell

# What you have now: PATH-restricted shell, but no kernel enforcement yet.
# Try escaping:
echo $PATH                          # only .sandbox/bin
which python3                        # .sandbox/bin/python3 -> /nix/store/.../python3
pip install requests                 # blocked by function armor

# Add kernel enforcement:
devbox run elevate
# Or in one step:
devbox run agent
```

## What's blocked

| Attempt | Caught by |
|---------|-----------|
| `pip install` | function armor (shell tier) |
| `npm install` | function armor (shell tier) |
| `echo pwned > /etc/test` | sandbox-exec (kernel tier — bash redirection) |
| `cat ~/.ssh/id_rsa` | sandbox-exec (denied path) |
| `curl https://example.com` | sandbox-exec (network deny) |
| `/usr/bin/python3 -c "import socket"` | sandbox-exec (binary not in read allowlist) |

## What's allowed

| Attempt | Why |
|---------|-----|
| `cat README.md` | inside workspace |
| `echo hi > test.txt` | workspace write |
| `git status` | git is in requisites.txt |
| `python3 -c "print(2+2)"` | python3 is allowlisted; computation only |
| `curl http://localhost:8080` | localhost allowed if `allow-localhost=true` |

## Trust properties

Nix-backed paths are input-addressed: `python3@3.12` always resolves to
the same `/nix/store/<hash>/bin/python3` for the same inputs. A tampered
binary would have a different hash and a different path, which the
allowlist would reject. The function armor is sourced automatically
when the sandboxed shell starts.
