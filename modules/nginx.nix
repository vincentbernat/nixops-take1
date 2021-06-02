args@{ config, lib, pkgs, ... }:

let
  pkgsWithModifiedMailcap = {
    # Update mailcap to replace application/javascript (IANA) with text/javascript (HTML WHATWG).
    # Also fix some others.
    mailcap = pkgs.mailcap.override {
      fetchzip = { ... } @ args:
        pkgs.fetchzip ({
          sha256 = "132477d9xsvfh96lz8d2zmlk235cmbfskcir6jgb1hlfvksfx1zr";
          postFetch = ''
                      ${args.postFetch}
                      sed -i -e "/^application\/javascript[ \t]/d" \
                             -e "/^text\/vnd.trolltech.linguist[ \t]/d" \
                             -e "1a text/javascript js;" \
                             -e "1a video/mp2t      ts;" \
                          $out/etc/nginx/mime.types
                      '';
        } // removeAttrs args [ "postFetch" "sha256" ]);
    };
  } // (removeAttrs pkgs ["mailcap"]);
in
(import <nixpkgs/nixos/modules/services/web-servers/nginx/default.nix> (
  {
    pkgs = pkgsWithModifiedMailcap;
  } // (removeAttrs args ["pkgs"])))
