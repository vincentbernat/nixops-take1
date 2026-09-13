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
            buildInputs = with pkgs; [
              curl
              hurl
              colordiff
              wdiff
              colmena
              nix
            ];
          };
        });
      apps = forAllSystems (system:
        let
          inherit (perSystem.${system}) pkgs;
        in
        {
          compare = {
            type = "app";
            meta.description = "Compare host derivations between two revisions";
            program = nixpkgs.lib.getExe (pkgs.writeShellApplication {
              name = "compare";
              runtimeInputs = with pkgs; [ colmena coreutils git jq nix-diff ];
              text = ''
                tmp=$(mktemp -d)
                trap 'rm -rf "$tmp"; git worktree prune' EXIT
                expr='{ nodes, lib, ... }: lib.mapAttrs (n: v: v.config.system.build.toplevel.drvPath) nodes'
                hosts() {
                  git worktree add --quiet --detach "$tmp/$1" "$2"
                  (cd "$tmp/$1" && colmena eval -E "$expr") > "$tmp/$1.json"
                }
                hosts old "''${1:-HEAD~1}"
                hosts new "''${2:-HEAD}"
                status=0
                while IFS=$'\t' read -r host old new; do
                  status=1
                  echo "=== $host"
                  if [ "$old" = - ]; then
                    echo "added"
                  elif [ "$new" = - ]; then
                    echo "removed"
                  else
                    nix-diff "$old" "$new"
                  fi
                done < <(jq -rn --slurpfile old "$tmp/old.json" --slurpfile new "$tmp/new.json" '
                  ($old[0] | keys) + ($new[0] | keys) | unique[] as $h
                  | select($old[0][$h] != $new[0][$h])
                  | [$h, $old[0][$h] // "-", $new[0][$h] // "-"] | @tsv')
                exit "$status"
              '';
            });
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
