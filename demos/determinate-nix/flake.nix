{
  description = "Modern Nix dev environment, sandbox-ready";

  # Pin nixpkgs for reproducibility. Update with: nix flake update
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bashInteractive
            coreutils
            findutils
            gnugrep
            gnused
            gawk
            diffutils
            git
            jq
            curl
            python312
            nodejs_20
            gnumake
          ];

          # Runs once per shell entry. Keeps sandbox prep out of the agent's
          # interactive session, but makes the artifacts available before
          # anything inside the shell runs.
          shellHook = ''
            ../../sbx/sbx prepare
            export PATH="$PWD/.sandbox/bin:$PATH"
            alias elevate='exec ../../sbx/sbx elevate'
            alias agent='exec ../../sbx/sbx elevate'
          '';
        };
      });
}
