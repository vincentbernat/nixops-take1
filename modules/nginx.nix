args@{ config, lib, pkgs, modulesPath, ... }:

let
  pkgsWithModifiedMailcap = pkgs // {
    # Update mailcap to add more types.
    mailcap = pkgs.mailcap.overrideAttrs (old: {
      postInstall = ''
        sed -i -e "/^text\/vnd.trolltech.linguist[ \t]/d" \
               -e "1a video/mp2t      ts;" \
            $out/etc/nginx/mime.types
      '';
    });
  };
in
(import "${modulesPath}/services/web-servers/nginx/default.nix"
  (args // { pkgs = pkgsWithModifiedMailcap; }))
