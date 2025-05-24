{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import inputs.nixpkgs { inherit system; };
          # Colmena has an issue with Nix 2.28
          # See: https://github.com/zhaofengli/colmena/issues/272
          nix = pkgs.nixVersions.nix_2_24;
          colmena = pkgs.colmena.override { inherit nix; };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "nixops-take1";
            buildInputs = [
              pkgs.curl
              pkgs.colordiff
              pkgs.wdiff
              colmena
              nix
            ];
          };
        }) // {
      colmena = import ./network.nix {
        inherit inputs;
      };
    };
}
