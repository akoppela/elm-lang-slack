{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/20.09") { }
}:
let
  buildInputs = (import ./nix/buildInputs.nix { inherit pkgs; }).all;

  devBuildInputs = [
    # Node
    pkgs.nodePackages.eslint
    pkgs.nodePackages.node2nix

    # Elm
    pkgs.elmPackages.elm-format
    pkgs.elm2nix
  ];
in
pkgs.mkShell {
  buildInputs = buildInputs ++ devBuildInputs;
}
