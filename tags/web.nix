{ config, pkgs, lib, ... }:
let
  vhost = name: attrs: {
    # Virtualhost definition
    services.nginx = {
      virtualHosts."${name}" = attrs // {
        root = "/data/webserver/${name}";
        sslTrustedCertificate =
          "/var/lib/acme/${attrs.useACMEHost or name}/full.pem";
        extraConfig = ''
          access_log /var/log/nginx/${name}.log anonymous;
          ${attrs.extraConfig or ""}
        '';
      } // (if !attrs ? useACMEHost then { enableACME = true; } else { });
    };

    # Let's encrypt extra configuration
    security.acme =
      lib.mkIf config.services.nginx.virtualHosts."${name}".enableACME {
        certs."${name}" = {
          webroot = lib.mkForce null;
          dnsProvider = "route53";
          credentialsFile = "/run/keys/acme-credentials.${name}.secret";
          extraDomainNames =
            let
              otherVhosts = lib.filterAttrs (n: v: v.useACMEHost == name)
                config.services.nginx.virtualHosts;
            in
            lib.mapAttrsToList (name: vhost: name) otherVhosts;
        };
      };
    deployment.keys =
      lib.mkIf config.services.nginx.virtualHosts."${name}".enableACME {
        "acme-credentials.${name}.secret" = {
          user = "acme";
          group = "nginx";
          permissions = "0640";
          keyCommand =
            let
              zoneid = (lib.importJSON ../cdktf.json).acme-zone.value;
              cmd = builtins.toFile
                "compile-acme-credentials.${name}"
                ''
                  source <(pass show personal/nixops/secrets)

                  cat <<EOF
                  AWS_REGION=us-east-1
                  AWS_ACCESS_KEY_ID=$ACME_AWS_ACCESS_KEY_ID
                  AWS_SECRET_ACCESS_KEY=$ACME_AWS_SECRET_ACCESS_KEY
                  AWS_HOSTED_ZONE_ID=${zoneid}
                  LEGO_EXPERIMENTAL_CNAME_SUPPORT=true
                  EOF
                '';
            in
            [ "${pkgs.runtimeShell}" "${cmd}" ];
        };
      };
    systemd.services =
      lib.mkIf config.services.nginx.virtualHosts."${name}".enableACME {
        "acme-${name}" = {
          requires = [ "acme-credentials.${name}.secret-key.service" ];
          after = [ "acme-credentials.${name}.secret-key.service" ];
        };
      };
  };

  vhosts =
    let
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
    in
    [

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

      # Insolites en Méné
      (vhost "insolites-en-mene.luffy.cx" {
        forceSSL = true;
        locations = {
          "/insolites-en-mene".extraConfig = "rewrite ^ / permanent;";
          "/roulotte-et-tipi".extraConfig = "rewrite ^ / permanent;";
          "/roulotte-western".extraConfig = "rewrite ^ / permanent;";
          "/tipi-camp".extraConfig = "rewrite ^ / permanent;";
          "/activites-et-decouvertes".extraConfig = "rewrite ^ / permanent;";
          "/activites-cenre-bretagne".extraConfig = "rewrite ^ / permanent;";
          "/decouverte-de-notre-region".extraConfig = "rewrite ^ / permanent;";
          "/nos-tarifs".extraConfig = "rewrite ^ / permanent;";
          "/nous-contacter".extraConfig = "rewrite ^ / permanent;";
          "/reservation".extraConfig = "rewrite ^ / permanent;";
          "/book-online".extraConfig = "rewrite ^ / permanent;";
        };
      })
      # (vhost "insolites-en-mene.fr" (redirectVhost "www.insolites-en-mene.fr"))
      # (vhost "www.insolites-en-mene.fr" {
      #   forceSSL = true;
      #   extraConfig = sts;
      # })

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
      (vhost "enx.io" (redirectVhost "www.enxio.fr"))
      (vhost "enxio.fr" (redirectVhost "www.enxio.fr"))
      (vhost "www.enx.io" (redirectVhost "www.enxio.fr"))
      (vhost "www.enxio.fr" {
        forceSSL = true;
        extraConfig = ''
          include /data/webserver/www.enxio.fr/nginx*.conf;
          ${sts}
        '';
      })
      (vhost "media.enxio.fr"
        (mediaVhost // { useACMEHost = "www.enxio.fr"; }))

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
      (vhost "bernat.ch" (redirectBlogVhost // {
        locations."= /.well-known/webfinger".extraConfig = ''
          if ($arg_resource = acct:vincent@bernat.ch) {
            return 302 https://hachyderm.io/.well-known/webfinger?resource=acct:vbernat@hachyderm.io;
          }
          return 404;
        '';
        locations."= /@vincent".extraConfig = ''
          return 302  https://hachyderm.io/@vbernat;
        '';
      }))
      (vhost "media.bernat.ch" (mediaVhost // { useACMEHost = "vincent.bernat.ch"; }))
      (vhost "media.luffy.cx" (mediaVhost // { useACMEHost = "luffy.cx"; }))
    ];
in
{
  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # nginx generic configuration
  services.nginx = {
    enable = true;

    package = (pkgs.nginxStable.override {
      # No stream module
      withStream = false;
      modules =
        let
          acceptlanguage = {
            name = "accept-language";
            src = pkgs.fetchFromGitHub {
              name = "accept-language";
              owner = "giom";
              repo = "nginx_accept_language_module";
              rev = "2f69842f83dac77f7d98b41a2b31b13b87aeaba7";
              hash = "sha256-fMENKki03aQmw2rX8gMmdwnGUBL4qsPHEAXOEmjWXsI=";
            };
            meta = with lib; {
              description = "Parse Accept-Language header";
              homepage = "https://github.com/giom/nginx_accept_language_module";
              license = with licenses; [ bsd2 ];
              maintainers = with maintainers; [ ];
            };
          };
        in
        with pkgs.nginxModules; [
          brotli
          ipscrub
          acceptlanguage
        ];
    }).overrideAttrs (old: {
      # See https://github.com/NixOS/nixpkgs/issues/182935
      disallowedReferences = [ ];
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
      worker_rlimit_nofile 8192;
    '';
    appendHttpConfig =
      let
        compressedTypes = ''
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
      in
      ''
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
  systemd.services.nginx.serviceConfig = {
    KillSignal = "QUIT";
    TimeoutStopSec = "120s";
    LogsDirectoryMode = lib.mkForce "0755";
  };

  # Logs
  services.logrotate.settings = {
    nginx = {
      frequency = "daily";
      rotate = 30;
      create = "0640 ${config.services.nginx.user} wheel";
      su = "${config.services.nginx.user} wheel";
    };
  };

  # Create root directories for vhost. They are not pure yet.
  system.activationScripts.nginxRoots =
    let
      nginxRoots = lib.mapAttrsToList (vhost: config: config.root)
        config.services.nginx.virtualHosts;
    in
    ''
      for d in ${builtins.concatStringsSep " " (map lib.escapeShellArg nginxRoots)}; do
        mkdir -p "$d"
        chown bernat:nginx "$d"
      done
    '';

  # Import vhosts and override nginx module to use a custom mailcap package
  imports = vhosts ++ [ ../modules/nginx.nix ];
  disabledModules = [ "services/web-servers/nginx/default.nix" ];
}
