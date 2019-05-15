{ config, pkgs, lib, nodes, ... }:
let
 vhost = name: attrs: let
   sameNodes = lib.filterAttrs (n: v: v.config.services.nginx.virtualHosts ? "${name}" &&
                                      (v.config.services.nginx.virtualHosts."${name}".enableACME ||
                                       v.config.services.nginx.virtualHosts."${name}".useACMEHost != null)) nodes;
   sameHosts = lib.mapAttrsToList (name: node: node.config.deployment.targetHost) sameNodes;
   nextNodes = lib.foldl (acc: host: if acc != [] then acc ++ [host] else
                  if host == config.deployment.targetHost then [host] else []) [] sameHosts;
   nextNode = if (builtins.length nextNodes) > 1 then builtins.elemAt nextNodes 1
                                                 else let
               first = builtins.elemAt sameHosts 0;
              in
               if first != config.deployment.targetHost then first else null;
 in
 { ... }: {
   # Virtualhost definition
   services.nginx = {
     virtualHosts."${name}" = {
       root = "/data/webserver/${name}";
       acmeFallbackHost = nextNode;
       sslTrustedCertificate = "${config.security.acme.directory}/${name}/full.pem";
       extraConfig =
         ''
           access_log /var/log/nginx/${name}.log anonymous;
           ${attrs.extraConfig or ""}
         '';
     } // (removeAttrs attrs ["extraConfig"])
       // (if !attrs ? useACMEHost then  {
             enableACME = true;
           } else {});
   };

   # Let's encrypt extra configuration
   security.acme = lib.mkIf config.services.nginx.virtualHosts."${name}".enableACME {
     certs."${name}" = {
       email = lib.concatStringsSep "@" ["letsencrypt" "vincent.bernat.ch"];
       extraDomains = let
         otherVhosts = lib.filterAttrs(n: v: v.useACMEHost == name) config.services.nginx.virtualHosts;
       in
         lib.listToAttrs (lib.mapAttrsToList (name: vhost: { name = name; value = null; }) otherVhosts);
     };
   };
 };
in
{
  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Use BBR
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = "bbr";

  # nginx generic configuration
  services.nginx = {
    enable = true;

    package = (pkgs.nginxStable.override {
      # Additional modules
      modules = [ pkgs.nginxModules.ipscrub ];
    }).overrideAttrs (oldAttrs: {
      # Use text/javascript instead of application/javascript
      postInstall = ''
        ${oldAttrs.postInstall}
        sed -i "s+application/javascript+text/javascript       +" $out/conf/mime.types
      '';
    });

    recommendedGzipSettings  = false; # we want more stuff in gzip_types
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

    # From https://mozilla.github.io/server-side-tls/ssl-config-generator/, intermediate level
    sslCiphers = lib.concatStringsSep ":" ["ECDHE-ECDSA-CHACHA20-POLY1305"
                                           "ECDHE-RSA-CHACHA20-POLY1305"
                                           "ECDHE-ECDSA-AES128-GCM-SHA256"
                                           "ECDHE-RSA-AES128-GCM-SHA256"
                                           "ECDHE-ECDSA-AES256-GCM-SHA384"
                                           "ECDHE-RSA-AES256-GCM-SHA384"
                                           "DHE-RSA-AES128-GCM-SHA256"
                                           "DHE-RSA-AES256-GCM-SHA384"
                                           "ECDHE-ECDSA-AES128-SHA256"
                                           "ECDHE-RSA-AES128-SHA256"
                                           "ECDHE-ECDSA-AES128-SHA"
                                           "ECDHE-RSA-AES256-SHA384"
                                           "ECDHE-RSA-AES128-SHA"
                                           "ECDHE-ECDSA-AES256-SHA384"
                                           "ECDHE-ECDSA-AES256-SHA"
                                           "ECDHE-RSA-AES256-SHA"
                                           "DHE-RSA-AES128-SHA256"
                                           "DHE-RSA-AES128-SHA"
                                           "DHE-RSA-AES256-SHA256"
                                           "DHE-RSA-AES256-SHA"
                                           "ECDHE-ECDSA-DES-CBC3-SHA"
                                           "ECDHE-RSA-DES-CBC3-SHA"
                                           "EDH-RSA-DES-CBC3-SHA"
                                           "AES128-GCM-SHA256"
                                           "AES256-GCM-SHA384"
                                           "AES128-SHA256"
                                           "AES256-SHA256"
                                           "AES128-SHA"
                                           "AES256-SHA"
                                           "DES-CBC3-SHA"
                                           "!DSS"];
    sslProtocols = "TLSv1 TLSv1.1 TLSv1.2 TLSv1.3";

    commonHttpConfig =
      ''
        # Logs
        ipscrub_period_seconds 86400;
        log_format anonymous '$remote_addr_ipscrub $ssl_cipher:$ssl_protocol $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';
        access_log /var/log/nginx/access.log anonymous;
        error_log stdout crit;
      '';

    appendConfig =
      ''
        pcre_jit on;
      '';
    appendHttpConfig =
      ''
        # SSL
        ssl_session_tickets off;

        # Default charset
        default_type application/octet-stream;
        charset utf-8;
        charset_types
          application/atom+xml
          application/javascript
          application/json
          application/rss+xml
          application/xml
          image/svg+xml
          text/css
          text/plain
          text/vcard
          text/vtt
          text/xml;

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

  # Logs
  systemd.services.nginx.serviceConfig.LogsDirectory = "nginx";
  services.logrotate = {
    enable = true;
    config = let
      path = "/var/log/nginx/*.log";
    in
      ''
        ${path} {
          daily
          missingok
          rotate 30
          compress
          delaycompress
          notifempty
          create 0640 ${config.services.nginx.user} wheel
          sharedscripts
          postrotate
            systemctl reload nginx
          endscript
        }
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
      globalRedirect = "vincent.bernat.ch";
      useACMEHost = "vincent.bernat.ch";
      extraConfig = stsWithPreload;
    };
    mediaVhost = {
      forceSSL = true;
      extraConfig =
        ''
          expires 30d;
          ${sts}
        '';
      # The following resources are expected to use cache busting.
      locations."/js".extraConfig =
        ''
          expires     max;
          add_header  Access-Control-Allow-Origin *;
          add_header  Cache-Control max-age=31536000,immutable;
        '';
      locations."/css".extraConfig =
        ''
          expires     max;
          add_header  Access-Control-Allow-Origin *;
          add_header  Cache-Control max-age=31536000,immutable;
        '';
      locations."/fonts".extraConfig =
        ''
          expires     max;
          add_header  Access-Control-Allow-Origin *;
          add_header  Cache-Control max-age=31536000,immutable;
          types {
            application/font-woff         woff;
            font/woff2                    woff2;
            application/x-font-truetype   ttf;
          }
        '';
      locations."= /favicon.ico".extraConfig = "expires 60d;";
      locations."/files".extraConfig = "expires 1d;";
      locations."/videos".extraConfig =
        ''
          expires 1d;
          add_header Access-Control-Allow-Origin *;
        '';
    };
  in
  [

   # HAProxy
   (vhost "haproxy.debian.net" {
     # Make dists and pool available without encryption
     addSSL = true;
     locations."~ ^/(dists|pool)".extraConfig =
       ''
         autoindex on;
       '';
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
     useACMEHost = "une-oasis-une-ecole.fr";
     extraConfig =
       ''
         include /data/webserver/www.une-oasis-une-ecole.fr/nginx*.conf;
         ${sts}
       '';
   })
   (vhost "media.une-oasis-une-ecole.fr" (mediaVhost // {
     useACMEHost = "une-oasis-une-ecole.fr";
   }))

   # Old website
   (vhost "luffy.cx" {
     forceSSL = true;
     globalRedirect = "www.luffy.cx";
     extraConfig = sts;
   })
   (vhost "www.luffy.cx" {
     forceSSL = true;
     extraConfig = sts;
     useACMEHost = "luffy.cx";
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
         rewrite ^ https://vincent.bernat.ch$uri permanent;
       '';
   })

   # Blog
   (vhost "vincent.bernat.ch" {
     forceSSL = true;
     extraConfig =
       ''
         include /data/webserver/vincent.bernat.ch/nginx*.conf;
       '';
   })
   (vhost "vincent.bernat.im" redirectBlogVhost)
   (vhost "bernat.im" redirectBlogVhost)
   (vhost "bernat.ch" redirectBlogVhost)
   (vhost "media.luffy.cx" (mediaVhost // {
     useACMEHost = "luffy.cx";
   }))
 ];
}
