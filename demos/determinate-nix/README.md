# determinate-nix demo (modern flakes workflow)

The modern Nix workflow — flakes + `nix develop` — sandbox-wrapped.

This demo works with **any Nix installation** that supports flakes:

- [Determinate Nix](https://determinate.systems/) (recommended for new installs)
- Upstream Nix (with `experimental-features = nix-command flakes` enabled)
- nix-darwin
- NixOS

If you're on a Determinate-installed Nix, this is your demo. The workflow
is identical for upstream Nix users with flakes enabled — Determinate just
ships flakes on by default and bundles a faster daemon (`dnixd`).

## Why this is different from `demos/direnv-nix/`

Two reasons to use this demo instead:

1. **Flakes are the modern Nix interface.** `flake.nix` with pinned inputs
   gives you reproducibility (nix-shell with `<nixpkgs>` does not). New
   Nix projects almost always start with a flake.

2. **No `nix-direnv` required for the non-direnv path.** `run-agent.sh`
   uses plain `nix develop --command` and works without any direnv setup.
   That's a meaningful onboarding difference for users coming from outside
   the Nix world.

Trust property is identical to the other Nix-backed demos: every binary
lives at `/nix/store/<hash>/bin/<n>`, input-addressed and immutable.

## Prerequisites

- macOS
- Nix installed with flakes enabled. Recommended:
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix \
    | sh -s -- install
  ```
- (Optional) [direnv](https://direnv.net) + [nix-direnv](https://github.com/nix-community/nix-direnv)
  for auto-activation on `cd`

## Run (with direnv)

```bash
direnv allow
cd .                 # enters the flake dev shell, runs sbx prepare
elevate              # adds kernel enforcement
# or:
agent                # one shot — full sandbox in a fresh shell
```

## Run (without direnv)

```bash
./run-agent.sh
```

This single command enters the flake dev shell, prepares the sandbox, and
re-execs under `sandbox-exec`. You're inside a fully-sandboxed shell when
it returns.

## What you get from Determinate specifically

If you installed Nix via Determinate's installer, you also get:

- Faster daemon (`dnixd`) — `nix develop` startup is noticeably quicker
- Lazy trees — large flake inputs don't materialize until needed
- Better default config — flakes on by default, sensible cache settings
- A clean uninstaller (`/nix/nix-installer uninstall`)

None of these change the sandbox boundary. They're quality-of-life
improvements on the Nix experience that this demo runs on top of.

## Caveats

- Flakes require `experimental-features = nix-command flakes` in your
  Nix config. Determinate enables this by default. Upstream installs
  do not — you'll need to add it to `~/.config/nix/nix.conf` or pass
  `--experimental-features` on the command line.
- The `flake.lock` file pins the exact nixpkgs revision. Commit it for
  team reproducibility. Update with `nix flake update` when you want
  newer packages.
