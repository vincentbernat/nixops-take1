args@{ config, lib, pkgs, ... }:

let
  pkgsWithModifiedMailcap = {
    # Update mailcap to replace application/javascript (IANA) with text/javascript (HTML WHATWG).
    # Also add text/vtt (IANA).
    mailcap = pkgs.mailcap.override {
      fetchzip = { ... } @ args:
        pkgs.fetchzip ({
          sha256 = "06yzyk8gxa12z0dbxsi8fphspi9mwmccy37n2kgxhf3p94rjyds6";
          postFetch = ''
                      ${args.postFetch}
                      sed -i -e "/^application\/javascript[ \t]/d" \
                             -e "1a text/javascript js;" \
                             -e "1a text/vtt        vtt;" \
                             -e "1a image/avif      avif;" \
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
