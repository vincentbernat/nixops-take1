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
  imports = let
    sts = "add_header Strict-Transport-Security \"max-age=31557600; includeSubDomains\";";
    stsWithPreload = "add_header Strict-Transport-Security \"max-age=31557600; includeSubDomains; preload\";";
    redirectBlogVhost = {
      forceSSL = true;
      globalRedirect = "vincent.bernat.im";
      extraConfig = stsWithPreload;
    };
    mediaVhost = {
      forceSSL = true;
      extraConfig =
        ''
          expires 30d;
          ${sts}
        '';
      locations."/js".extraConfig =
        ''
          expires     max;
          add_header  Access-Control-Allow-Origin *;
          add_header  Cache-Control immutable;
        '';
      locations."/css".extraConfig =
        ''
          expires     max;
          add_header  Access-Control-Allow-Origin *;
          add_header  Cache-Control immutable;
        '';
      locations."/fonts".extraConfig =
        ''
          expires     max;
          add_header  Access-Control-Allow-Origin *;
          add_header  Cache-Control immutable;
          types {
            application/font-woff         woff;
            font/woff2                    woff2;
            application/x-font-truetype   ttf;
          }
        '';
      locations."= /favicon.ico".extraConfig = "expires 60d;";
      locations."/files".extraConfig = "expires 1d;";
      locations."~ .m3u8$".extraConfig =
        ''
          expires 1d;
          add_header  Access-Control-Allow-Origin *;
        '';
    };
  in
  [

   # HAProxy
   (vhost "haproxy.debian.net" {
     # Make dists and pool available without encryption
     addSSL = true;
     locations."~ ^/(dists|pool)".extraConfig = "";
     locations."/".extraConfig =
       ''
         if ($scheme = http) {
           # Safe usage of if-in-location
           return 301 https://$host$request_uri;
         }
       '';
   })

   # Une Oasis Une École
   (vhost "une-oasis-une-ecole.fr" {
     forceSSL = true;
     globalRedirect = "www.une-oasis-une-ecole.fr";
     extraConfig = sts;
   })
   (vhost "www.une-oasis-une-ecole.fr" {
     forceSSL = true;
     extraConfig = sts;
   })
   (vhost "media.une-oasis-une-ecole.fr" mediaVhost)

   # Old website
   (vhost "www.luffy.cx" {
     forceSSL = true;
     extraConfig = sts;
     locations."/wiremaps".extraConfig =
       ''
         rewrite ^ https://github.com/vincentbernat/wiremaps/archives/master permanent;
       '';
     locations."/udpproxy".extraConfig =
       ''
         rewrite ^ https://github.com/vincentbernat/udpproxy/archives/master permanent;
       '';
     locations."/snimpy".extraConfig =
       ''
         rewrite ^ https://github.com/vincentbernat/snimpy/archives/master permanent;
       '';
     locations."/lldpd".extraConfig =
       ''
         rewrite ^ https://github.com/vincentbernat/lldpd/archives/master permanent;
       '';
     locations."/".extraConfig =
       ''
         rewrite ^ https://vincent.bernat.im$uri permanent;
       '';
   })

   # Blog
   (vhost "vincent.bernat.im" {
     forceSSL = true;
     extraConfig =
       ''
         include /data/webserver/vincent.bernat.im/nginx*.conf;
         expires 1h;
       '';
   })
   (vhost "bernat.im" redirectBlogVhost)
   (vhost "bernat.ch" redirectBlogVhost)
   (vhost "vincent.bernat.ch" redirectBlogVhost)
   (vhost "media.luffy.cx" mediaVhost)
 ];
}
