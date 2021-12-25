args@{ config, lib, pkgs, ... }:

let
  pkgsWithModifiedMailcap = pkgs // {
    # Update mailcap to replace application/javascript (IANA) with text/javascript (HTML WHATWG).
    # Also fix some others.
    mailcap = pkgs.mailcap.override {
      fetchzip = { ... } @ args:
        pkgs.fetchzip (args // {
          sha256 = "5n8JlCeXXCTL7aFDyQ+knIgPHJyouDuwulM0dCX3mh4=";
          postFetch = ''
                      ${args.postFetch}
                      sed -i -e "/^application\/javascript[ \t]/d" \
                             -e "/^text\/vnd.trolltech.linguist[ \t]/d" \
                             -e "1a text/javascript js;" \
                             -e "1a video/mp2t      ts;" \
                          $out/etc/nginx/mime.types
                      '';
        });
    };
  };
in
(import <nixpkgs/nixos/modules/services/web-servers/nginx/default.nix>
  (args // {pkgs = pkgsWithModifiedMailcap; }))
