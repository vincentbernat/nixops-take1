{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages."${system}";
        in
        {
          devShell = pkgs.mkShell {
            name = "nixops-take1";
            buildInputs = [
              pkgs.curl
              pkgs.colordiff
              pkgs.wdiff
              pkgs.nixopsUnstable
            ];
            shellHook = ''
              export NIXOPS_DEPLOYMENT=luffy
              export NIXOPS_STATE=state.nixops
            '';
          };
        }) // {
      nixopsConfigurations.default = import ./network.nix { inherit inputs; };
    };
}
