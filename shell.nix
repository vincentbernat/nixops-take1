let
  version = "21.11";
  nixpkgs = "https://github.com/NixOS/nixpkgs/archive/nixos-${version}.tar.gz";
  pkgs = import (fetchTarball nixpkgs) {};
in
pkgs.mkShell {
  name = "nixops-take1";
  buildInputs = [
    pkgs.nixopsUnstable
  ];
  shellHook = ''
    export NIX_PATH=nixpkgs=${nixpkgs}
    export NIXOPS_DEPLOYMENT=luffy
    export NIXOPS_STATE=state.nixops
  '';
}
