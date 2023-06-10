{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import inputs.nixpkgs
            {
              inherit system;
              config = {
                permittedInsecurePackages = [ "python3.10-certifi-2022.9.24" ];
              };
            };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "nixops-take1";
            buildInputs = [
              pkgs.curl
              pkgs.colordiff
              pkgs.wdiff
              pkgs.nixopsUnstable
              pkgs.nix
            ];
            shellHook = ''
              export NIXOPS_DEPLOYMENT=luffy
              export NIXOPS_STATE=state.nixops
            '';
          };
        }) // {
      nixopsConfigurations.default = import ./network.nix {
        inherit inputs;
      };
    };
}
