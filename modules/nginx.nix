args@{ config, lib, pkgs, modulesPath, ... }:

let
  pkgsWithModifiedMailcap = pkgs // {
    # Update mailcap to replace application/javascript (IANA) with text/javascript (HTML WHATWG).
    # Also fix some others.
    mailcap = pkgs.mailcap.overrideAttrs (old: {
      postInstall = ''
        sed -i -e "/^application\/javascript[ \t]/d" \
               -e "/^text\/vnd.trolltech.linguist[ \t]/d" \
               -e "1a text/javascript js;" \
               -e "1a video/mp2t      ts;" \
            $out/etc/nginx/mime.types
      '';
    });
  };
in
(import "${modulesPath}/services/web-servers/nginx/default.nix"
  (args // { pkgs = pkgsWithModifiedMailcap; }))
