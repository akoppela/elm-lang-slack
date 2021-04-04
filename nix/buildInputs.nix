{ pkgs }: rec {
  nodejs = pkgs.nodejs-14_x;

  all = [
    nodejs
    pkgs.elmPackages.elm
  ];
}
