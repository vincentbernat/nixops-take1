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
              dnsutils
              hurl
              jq
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
          certificates = {
            type = "app";
            meta.description = "Request TLS certificates and store them in pass";
            program = nixpkgs.lib.getExe (pkgs.writeShellApplication {
              name = "certificates";
              runtimeInputs = with pkgs; [ colmena coreutils diffutils findutils gnused jq lego openssl ];
              text = ''
                umask 077

                # With --staging, request all certificates from the staging
                # environment and do not store them.
                staging=0
                case "''${1:-}" in
                  --staging) staging=1 ;;
                  "") ;;
                  *)
                    echo "Usage: $0 [--staging]" >&2
                    exit 1
                    ;;
                esac

                email=${nixpkgs.lib.concatStringsSep "@" [ "letsencrypt" "vincent.bernat.ch" ]}
                pass=personal/nixops/tls
                server=acme-v02.api.letsencrypt.org
                if [ "$staging" -eq 1 ]; then
                  server=acme-staging-v02.api.letsencrypt.org
                fi

                tmp=$(mktemp -d)
                trap 'rm -rf "$tmp"' EXIT

                # Hosts find the certificate with its first name, so it should be
                # the same on all of them.
                expr='{ nodes, lib, ... }: lib.zipAttrsWith
                  (cert: lists:
                    let names = lib.sort
                      (a: b: lib.stringLength a < lib.stringLength b || (lib.stringLength a == lib.stringLength b && a < b))
                      (lib.unique (lib.concatLists lists));
                    in if lib.all (l: builtins.head l == builtins.head names) lists then names
                    else throw (cert + ": first name is not the same on all hosts"))
                  (lib.mapAttrsToList (_: n: n.config.luffy.caddy.certificates) nodes)'
                colmena eval -E "$expr" \
                  | jq -r 'to_entries[] | [.key, (.value | join(" "))] | @tsv' \
                  > "$tmp/certificates.tsv"

                RFC2136_TSIG_SECRET=$(pass show personal/nixops/dns/acme.luffy.cx/tsig/update.acme.luffy.cx)
                export RFC2136_TSIG_SECRET
                export RFC2136_NAMESERVER=nsupdate.luffy.cx:53
                export RFC2136_TSIG_KEY=update.acme.luffy.cx.
                export RFC2136_TSIG_ALGORITHM=hmac-sha256.

                # Lego state (account and certificates) is stored in pass as a
                # JSON object mapping each file path to its content.
                state="$tmp/lego"
                mkdir "$state"
                if [ "$staging" -eq 0 ] && pass show "$pass/lego" > "$tmp/lego.json" 2> /dev/null; then
                  jq -r 'keys[]' "$tmp/lego.json" | while read -r path; do
                    mkdir -p "$(dirname "$state/$path")"
                    jq -j --arg path "$path" '.[$path]' "$tmp/lego.json" > "$state/$path"
                  done
                fi

                status=0
                while IFS=$'\t' read -r cert names; do
                  read -ra list <<< "$names"
                  args=()
                  for name in "''${list[@]}"; do
                    args+=(--domains "$name")
                  done
                  file="$state"/certificates/''${list[0]//\*/_}

                  # With an account and a previous certificate with the same names,
                  # lego renews it when ARI says so or when less than 30 days are
                  # left. Otherwise, request a new one.
                  action=(run)
                  if [ -d "$state/accounts" ] && [ -f "$file.crt" ] \
                      && [ "$(openssl x509 -in "$file.crt" -noout -ext subjectAltName \
                              | sed -e 1d -e 's/ //g' | tr , '\n' | sed 's/^DNS://' \
                              | sort | paste -sd ' ')" \
                           = "$(tr ' ' '\n' <<< "$names" | sort | paste -sd ' ')" ]; then
                    action=(renew --no-random-sleep)
                  fi

                  echo "### $cert: $names"
                  if ! lego --accept-tos --server "https://$server/directory" --email "$email" \
                      --path "$state" --key-type ec256 --dns rfc2136 \
                      "''${args[@]}" "''${action[@]}"; then
                    status=1
                    continue
                  fi
                  [ "$staging" -eq 0 ] || continue
                  (cd "$state" && find . -type f -printf '%P\0' | xargs -0 -n1 jq -Rs '{(input_filename): .}') \
                    | jq -sS add > "$tmp/new.json"
                  if ! cmp -s "$tmp/new.json" "$tmp/lego.json"; then
                    pass add -m -f "$pass/lego" < "$tmp/new.json" > /dev/null
                    mv "$tmp/new.json" "$tmp/lego.json"
                  fi
                done < "$tmp/certificates.tsv"
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
