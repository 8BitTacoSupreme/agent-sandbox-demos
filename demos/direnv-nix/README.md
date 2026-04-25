# direnv + nix-shell demo

The classic "Nix without committing to Flox or devbox" stack:

- `shell.nix` declares the environment in plain Nix
- `direnv` activates it when you `cd` into the directory
- `sbx` wraps the resulting binary set in a sandbox

Trust property is identical to the devbox demo — every binary lives at
an input-addressed `/nix/store/<hash>/bin/<n>` path. The wiring is
just glued together with shell hooks instead of a JSON config.

## Prerequisites

- macOS
- [Nix](https://nixos.org/download) installed (the [Determinate Nix](https://determinate.systems) installer is recommended)
- [direnv](https://direnv.net) installed (`brew install direnv`)
- direnv hooked into your shell ([instructions](https://direnv.net/docs/hook.html))
- `nix-direnv` for caching is recommended (otherwise nix-shell rebuilds on every cd):
  `nix-env -iA nixpkgs.nix-direnv`

## Run

```bash
# First time: allow the .envrc
direnv allow

# cd in — direnv runs nix-shell, then sbx prepare, then prepends .sandbox/bin to PATH
cd .

# Add kernel enforcement
elevate
# Or run a shell inside the full sandbox
agent
```

## Why this stack matters

For users who:

- Are already on Nix but don't want the Flox dependency
- Want plain `shell.nix` they can commit and edit
- Already have direnv as their activation mechanism

It's the lowest-glue path to the Nix trust property.

## Caveat

`use nix` (without `nix-direnv`) re-runs nix-shell on every `cd`, which
is slow. Install `nix-direnv` and use `use flake` (with a flake.nix) or
`use_nix` (cached) for a usable workflow.
