{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };
  outputs = { self, nixpkgs, ... }@inputs:
    let
      systems = nixpkgs.lib.systems.flakeExposed;
      forAllSystems = nixpkgs.lib.genAttrs systems;
      perSystem = forAllSystems (system: {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      });
    in
    {
      packages = forAllSystems (system: perSystem.${system}.pkgs.luffy);
      devShells = forAllSystems (system:
        let
          inherit (perSystem.${system}) pkgs;
        in
        {
          default = pkgs.mkShell {
            name = "nixops-take1";
            buildInputs = [
              pkgs.curl
              pkgs.hurl
              pkgs.colordiff
              pkgs.wdiff
              pkgs.colmena
              pkgs.nix
            ];
          };
        });
      # Packages we build ourselves, available as `pkgs.luffy.*'.
      overlays.default = final: prev: {
        luffy = final.lib.packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ./packages;
        };
      };
      colmena = import ./network.nix {
        inherit inputs;
      };
    };
}
