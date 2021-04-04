let
  pkgs =
    import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/20.09") { };

  buildInputs = import ./nix/buildInputs.nix { inherit pkgs; };

  nodeDependencies =
    (pkgs.callPackage ./nix/node/default.nix {
      inherit pkgs;
      inherit (buildInputs) nodejs;
    }).shell.nodeDependencies;

  configureNode = ''
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
  '';

  configureElm = pkgs.elmPackages.fetchElmDeps {
    elmPackages = import ./nix/elm/elm-srcs.nix;
    registryDat = ./nix/elm/registry.dat;
    elmVersion = "0.19.1";
  };
in
pkgs.stdenv.mkDerivation {
  name = "elm-lang-slack";
  src = ./.;

  buildInputs = buildInputs.all;

  configurePhase = configureNode + configureElm;

  buildPhase = ''
    npm run build
  '';

  installPhase = ''
    cp -r release $out/
  '';
}
