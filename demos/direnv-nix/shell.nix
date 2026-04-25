# Plain Nix expression — no Flox, no devbox, just nix-shell
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
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
}
