{ pkgs }:
pkgs.elmPackages.fetchElmDeps {
  elmPackages = import ./elm-srcs.nix;
  registryDat = ./registry.dat;
  elmVersion = "0.19.1";
}
