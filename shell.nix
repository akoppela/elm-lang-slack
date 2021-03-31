{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/20.09") { }
}:
pkgs.mkShell {
  buildInputs = [
    # Node
    pkgs.nodejs-14_x
    pkgs.nodePackages.eslint

    # Elm
    pkgs.elmPackages.elm
    pkgs.elmPackages.elm-format
  ];
}
