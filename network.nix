let
  lib = import <nixpkgs/lib>;
  web = idx: {
    deployment.targetHost = "web${lib.fixedWidthNumber 2 idx}.luffy.cx";
    networking.hostName = "web${lib.fixedWidthNumber 2 idx}.luffy.cx";
    imports = [
      ./exoscale.nix
      ./common.nix
      ./web.nix
    ];
  };
in
{
  network.description = "Luffy infrastructure";
  web01 = web 1;
  web02 = web 2;
}
