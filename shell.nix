{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/20.09") { }
}:
pkgs.mkShell {
  buildInputs = [
    pkgs.nodejs-14_x
    pkgs.nodePackages.eslint
  ];
}
