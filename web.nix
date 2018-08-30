{ config, pkgs, lib, nodes, ... }:
let
 vhost = name: attrs: let
   sameNodes = lib.filterAttrs (n: v: v.config.services.nginx.virtualHosts."${name}".enableACME) nodes;
   sameHosts = lib.mapAttrsToList (name: node: node.config.deployment.targetHost) sameNodes;
   nextNodes = lib.foldl (acc: host: if acc != [] then acc ++ [host] else
                  if host == config.deployment.targetHost then [host] else []) [] sameHosts;
   nextNode = if (builtins.length nextNodes) > 1 then builtins.elemAt nextNodes 1 else null;
 in
 { ... }: {
   # Virtualhost definition
   services.nginx = {
     virtualHosts."${name}" = {
       root = "/data/webserver/${name}";
       enableACME = true;
       forceSSL = true;
       acmeFallbackHost = nextNode;
     } // attrs;
   };

   # Let's encrypt extra configuration
   security.acme = {
     certs."${name}" = {
       email = lib.concatStringsSep "@" ["letsencrypt" "vincent.bernat.ch"];
     };
   };
 };
in
{
  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Don't use production ACME
  security.acme.production = false;

  # nginx generic configuration
  services.nginx = {
    enable = true;

    recommendedGzipSettings  = false;
    recommendedOptimisation  = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;
    sslDhparam = pkgs.writeText "dhparam.pem"
      ''
      -----BEGIN DH PARAMETERS-----
      MIIBCAKCAQEA9MKu+OBtsJcYjeYMa8Y855WbHfQ5A2cCH7paxS5ildmZSBhxiNAP
      y/bBCtaeAXFzJGojRtuPxoEQZS45h1ZcMHLG+QV7VWoJLv6EUWy2/snpLuTXPbeZ
      B6/I2uNY/px8NOx+RObmQ92PUBsBQjJrmSShjFqGqC5vuNjenPh0NXTFqoVDb+ZP
      OhsHnSuYWyphsegz6W7oEg3zzxq8n9cGjTLqoq3+KRYwq8Nalc1e6u540jm/kYAu
      G4izxejVfu0gw2/86QNNA4V1BJSSkKek7IczFVaRmUMBiiGz1LJVNolvVPcPoL4X
      vEQ5XXZQL17b3umXUao8M+MPH6cvrXfCAwIBAg==
      -----END DH PARAMETERS-----
      '';

    appendHttpConfig =
      ''
        # Enable gzip compression
        gzip on;
        gzip_disable "msie6";
        gzip_proxied any;
        gzip_comp_level 5;
        gzip_vary on;
        gzip_types
          application/atom+xml
          application/javascript
          application/json
          application/ld+json
          application/manifest+json
          application/rss+xml
          application/vnd.apple.mpegurl
          application/vnd.geo+json
          application/vnd.ms-fontobject
          application/x-font-ttf
          application/x-web-app-manifest+json
          application/xhtml+xml
          application/xml
          application/xml+rss
          font/opentype
          image/svg+xml
          text/cache-manifest
          text/css
          text/javascript
          text/plain
          text/vcard
          text/vtt
          text/xml;
      '';
  };

  # Create root directories for vhost. They are not pure yet.
  system.activationScripts.nginxRoots = let
    nginxRoots = lib.mapAttrsToList (vhost: config: config.root) config.services.nginx.virtualHosts;
  in
    ''
      for d in ${builtins.concatStringsSep " " nginxRoots}; do
        mkdir -p ''${d}
        chown bernat:nginx ''${d}
      done
    '';

  # Virtual hosts
  imports = [
   (vhost "vincent.bernat.im" {
     extraConfig =
       ''
         include /data/webserver/vincent.bernat.im/nginx*.conf;
         expires 1h;
       '';
   })
 ];
}
