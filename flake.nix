{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        stable.follows = "nixpkgs";
      };
    };
  };
  outputs = { self, nixpkgs, flake-utils, colmena, ... }@inputs:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import inputs.nixpkgs { inherit system; };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "nixops-take1";
            buildInputs = [
              pkgs.curl
              pkgs.colordiff
              pkgs.wdiff
              colmena.packages."${system}".colmena
              pkgs.nix
            ];
          };
        }) // {
      colmenaHive = colmena.lib.makeHive self.outputs.colmena;
      colmena = import ./network.nix {
        inherit inputs;
      };
    };
}
