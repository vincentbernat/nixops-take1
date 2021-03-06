{ config, pkgs, lib, nodes, ... }:
let
  vhost = name: attrs:
    let
      sameNodes = lib.filterAttrs (n: v:
        v.config.services.nginx.virtualHosts ? "${name}"
        && (v.config.services.nginx.virtualHosts."${name}".enableACME
          || v.config.services.nginx.virtualHosts."${name}".useACMEHost
          != null)) nodes;
      sameHosts =
        lib.mapAttrsToList (name: node: node.config.deployment.targetHost)
        sameNodes;
      nextNodes = lib.foldl (acc: host:
        if acc != [ ] then
          acc ++ [ host ]
        else if host == config.deployment.targetHost then
          [ host ]
        else
          [ ]) [ ] sameHosts;
      nextNode = if (builtins.length nextNodes) > 1 then
        builtins.elemAt nextNodes 1
      else
        let first = builtins.elemAt sameHosts 0;
        in if first != config.deployment.targetHost then first else null;
    in { ... }: {
      # Virtualhost definition
      services.nginx = {
        virtualHosts."${name}" = {
          root = "/data/webserver/${name}";
          acmeFallbackHost = nextNode;
          sslTrustedCertificate =
            "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"; # Buypass use a different certificate for OCSP
          extraConfig = ''
            access_log /var/log/nginx/${name}.log anonymous;
            ${attrs.extraConfig or ""}
          '';
        } // (removeAttrs attrs [ "extraConfig" ])
          // (if !attrs ? useACMEHost then { enableACME = true; } else { });
      };

      # Let's encrypt extra configuration
      security.acme =
        lib.mkIf config.services.nginx.virtualHosts."${name}".enableACME {
          certs."${name}" = {
            extraDomainNames = let
              otherVhosts = lib.filterAttrs (n: v: v.useACMEHost == name)
                config.services.nginx.virtualHosts;
            in lib.mapAttrsToList (name: vhost: name) otherVhosts;
          };
        };
    };
  vhosts = let
    cors = ''
      add_header  Access-Control-Allow-Origin *;
    '';
    sts = ''
      add_header Strict-Transport-Security "max-age=31557600; includeSubDomains";'';
    stsWithPreload = ''
      add_header Strict-Transport-Security "max-age=31557600; includeSubDomains; preload";'';
    redirectVhost = to: {
      addSSL = true;
      globalRedirect = to;
      useACMEHost = to;
      extraConfig = sts;
    };
    redirectBlogVhost = (redirectVhost "vincent.bernat.ch") // {
      extraConfig = stsWithPreload;
    };
    mediaVhost = {
      forceSSL = true;
      extraConfig = ''
        expires 30d;
        ${sts}
      '';
      # The following resources are expected to use cache busting.
      locations."/js".extraConfig = ''
        expires     max;
        add_header  Cache-Control immutable;
        ${cors}
        ${sts}
      '';
      locations."/css".extraConfig = ''
        expires     max;
        add_header  Cache-Control immutable;
        ${cors}
        ${sts}
      '';
      locations."/fonts".extraConfig = ''
        expires     max;
        add_header  Cache-Control immutable;
        ${cors}
        ${sts}
        types {
          application/font-woff         woff;
          font/woff2                    woff2;
          application/x-font-truetype   ttf;
        }
      '';
      locations."= /favicon.ico".extraConfig = "expires 60d;";
      locations."/files".extraConfig = "expires 1d;";
      locations."/videos".extraConfig = ''
        expires 1d;
        ${cors}
        ${sts}
      '';
      locations."/images".extraConfig = ''
        ${cors}
        ${sts}
      '';
      locations."~ ^/images/.*\\.(png|jpe?g)$".extraConfig = ''
        ${cors}
        ${sts}
        add_header Vary Accept;
        try_files $uri$avif_suffix$webp_suffix $uri$avif_suffix $uri$webp_suffix $uri =404;
      '';
    };
  in [

    # HAProxy
    (vhost "haproxy.debian.net" {
      # Make dists and pool available without encryption
      addSSL = true;
      locations."~ ^/(dists|pool)".extraConfig = ''
        autoindex on;
      '';
      locations."/".extraConfig = ''
        if ($scheme = http) {
          # Safe usage of if-in-location
          return 301 https://$host$request_uri;
        }
      '';
    })

    # Une Oasis Une École
    (vhost "une-oasis-une-ecole.fr" (redirectVhost "www.une-oasis-une-ecole.fr"))
    (vhost "www.une-oasis-une-ecole.fr" {
      forceSSL = true;
      extraConfig = ''
        include /data/webserver/www.une-oasis-une-ecole.fr/nginx*.conf;
        ${sts}
      '';
    })
    (vhost "media.une-oasis-une-ecole.fr"
      (mediaVhost // { useACMEHost = "www.une-oasis-une-ecole.fr"; }))

    # ENXIO
    (vhost "enx.io" (redirectVhost "www.enx.io"))
    (vhost "enxio.fr" (redirectVhost "www.enx.io"))
    (vhost "www.enxio.fr" (redirectVhost "www.enx.io"))
    (vhost "www.enx.io" {
      forceSSL = true;
      extraConfig = ''
        include /data/webserver/www.enx.io/nginx*.conf;
        ${sts}
      '';
    })
    (vhost "media.enx.io"
      (mediaVhost // { useACMEHost = "www.enx.io"; }))

    # Old website
    (vhost "luffy.cx" {
      addSSL = true;
      globalRedirect = "www.luffy.cx";
      extraConfig = sts;
    })
    (vhost "www.luffy.cx" {
      forceSSL = true;
      extraConfig = sts;
      useACMEHost = "luffy.cx";
      locations."/wiremaps".extraConfig = ''
        rewrite ^ https://github.com/vincentbernat/wiremaps permanent;
      '';
      locations."/udpproxy".extraConfig = ''
        rewrite ^ https://github.com/vincentbernat/udpproxy permanent;
      '';
      locations."/snimpy".extraConfig = ''
        rewrite ^ https://github.com/vincentbernat/snimpy permanent;
      '';
      locations."/lldpd".extraConfig = ''
        rewrite ^ https://lldpd.github.io permanent;
      '';
      locations."/".extraConfig = ''
        rewrite ^ https://vincent.bernat.ch$request_uri permanent;
      '';
    })

    # Blog
    (vhost "vincent.bernat.ch" {
      forceSSL = true;
      extraConfig = ''
        include /data/webserver/vincent.bernat.ch/nginx*.conf;
      '';
    })
    (vhost "vincent.bernat.im" redirectBlogVhost)
    (vhost "bernat.im" redirectBlogVhost)
    (vhost "bernat.ch" redirectBlogVhost)
    (vhost "media.luffy.cx" (mediaVhost // { useACMEHost = "luffy.cx"; }))
  ];
in {
  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Use BBR
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = "bbr";

  # Let's Encrypt
  security.acme = {
    acceptTerms = true;
    email = lib.concatStringsSep "@" [ "buypass+${config.deployment.targetHost}"
                                       "vincent.bernat.ch" ];
    server = "https://api.buypass.com/acme/directory";
  };

  # nginx generic configuration
  services.nginx = {
    enable = true;

    package = (pkgs.nginxStable.override {
      # No stream module
      withStream = false;
      modules = with pkgs.nginxModules; [
        brotli
        ipscrub
      ];
    });

    recommendedGzipSettings = false; # we want more stuff in gzip_types
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    sslDhparam = pkgs.writeText "dhparam.pem" ''
      -----BEGIN DH PARAMETERS-----
      MIIBCAKCAQEA9MKu+OBtsJcYjeYMa8Y855WbHfQ5A2cCH7paxS5ildmZSBhxiNAP
      y/bBCtaeAXFzJGojRtuPxoEQZS45h1ZcMHLG+QV7VWoJLv6EUWy2/snpLuTXPbeZ
      B6/I2uNY/px8NOx+RObmQ92PUBsBQjJrmSShjFqGqC5vuNjenPh0NXTFqoVDb+ZP
      OhsHnSuYWyphsegz6W7oEg3zzxq8n9cGjTLqoq3+KRYwq8Nalc1e6u540jm/kYAu
      G4izxejVfu0gw2/86QNNA4V1BJSSkKek7IczFVaRmUMBiiGz1LJVNolvVPcPoL4X
      vEQ5XXZQL17b3umXUao8M+MPH6cvrXfCAwIBAg==
      -----END DH PARAMETERS-----
    '';

    commonHttpConfig = ''
      # Logs
      ipscrub_period_seconds 86400;
      log_format anonymous '$remote_addr_ipscrub $ssl_cipher:$ssl_protocol $remote_user [$time_local] '
                  '"$request" $status $body_bytes_sent '
                  '"$http_referer" "$http_user_agent"';
      access_log /var/log/nginx/access.log anonymous;
    '';

    appendConfig = ''
      pcre_jit on;
    '';
    appendHttpConfig = let compressedTypes = ''
      application/atom+xml
      application/json
      application/ld+json
      application/manifest+json
      application/rss+xml
      application/vnd.apple.mpegurl
      application/vnd.geo+json
      application/vnd.ms-fontobject
      application/wasm
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
      text/xml
    '';
    in ''
      # Default charset
      charset utf-8;
      charset_types
        application/atom+xml
        application/json
        application/rss+xml
        application/xml
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/vcard
        text/vtt
        text/xml;

      # Enable gzip compression
      gzip on;
      gzip_proxied any;
      gzip_comp_level 6;
      gzip_vary on;
      gzip_types
        ${compressedTypes};
      # Enable brotli compression
      brotli on;
      brotli_comp_level 6;
      brotli_types
        ${compressedTypes};

      map $http_accept $webp_suffix {
        default        "";
        "~image/webp"  ".webp";
      }
      map $http_accept $avif_suffix {
        default        "";
        "~image/avif"  ".avif";
      }
    '';
  };

  # Reload/restart logic. This could be enhanced once we have
  # https://github.com/systemd/systemd/issues/13284
  services.nginx.enableReload = true;
  systemd.services.nginx.serviceConfig.KillSignal = "QUIT";
  systemd.services.nginx.serviceConfig.TimeoutStopSec = "120s";

  # Logs
  services.logrotate = {
    enable = true;
    extraConfig = let path = "/var/log/nginx/*.log";
    in ''
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
    nginxRoots = lib.mapAttrsToList (vhost: config: config.root)
      config.services.nginx.virtualHosts;
  in ''
    for d in ${builtins.concatStringsSep " " nginxRoots}; do
      mkdir -p ''${d}
      chown bernat:nginx ''${d}
    done
  '';

  # Virtual hosts
  imports = vhosts ++ [ ./modules/nginx.nix ];
  disabledModules = [ "services/web-servers/nginx/default.nix" ];
}
