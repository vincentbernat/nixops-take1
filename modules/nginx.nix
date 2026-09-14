{ config, pkgs, lib, ... }:
let
  cfg = config.luffy.nginx;
  vhosts = config.services.nginx.virtualHosts;
  acmeCredentials = name:
    let
      zoneid = (lib.importJSON ../cdktf.json).acme-zone.value;
    in
    builtins.toFile "compile-acme-credentials.${name}" ''
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
{
  options.luffy.nginx.enable = lib.mkEnableOption "nginx";

  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
      options.luffy.acmeDNS = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to get the certificate with a DNS challenge through Route 53.";
      };
      config = {
        root = lib.mkDefault "/data/webserver/${name}";
        enableACME = lib.mkDefault (config.useACMEHost == null);
        sslTrustedCertificate = lib.mkDefault "/var/lib/acme/${lib.defaultTo name config.useACMEHost}/full.pem";
        extraConfig = lib.mkBefore "access_log /var/log/nginx/${name}.log anonymous;";
      };
    }));
  };

  config = lib.mkMerge [
    # Let's Encrypt certificates through Route 53
    {
      security.acme.certs = lib.mapAttrs
        (name: vhost: lib.mkIf (vhost.enableACME && vhost.luffy.acmeDNS) {
          webroot = lib.mkForce null;
          dnsProvider = "route53";
          environmentFile = "/run/keys/acme-credentials.${name}.secret";
          extraDomainNames = lib.attrNames (lib.filterAttrs (_: v: v.useACMEHost == name) vhosts);
        })
        vhosts;
      deployment.keys = lib.mapAttrs'
        (name: vhost: lib.nameValuePair "acme-credentials.${name}.secret" (lib.mkIf (vhost.enableACME && vhost.luffy.acmeDNS) {
          user = "acme";
          group = "nginx";
          permissions = "0640";
          uploadAt = "post-activation";
          keyCommand = [ "${pkgs.runtimeShell}" "${acmeCredentials name}" ];
        }))
        vhosts;
      systemd.services = lib.mapAttrs'
        (name: vhost: lib.nameValuePair "acme-${name}" (lib.mkIf (vhost.enableACME && vhost.luffy.acmeDNS) {
          requires = [ "acme-credentials.${name}.secret-key.service" ];
          after = [ "acme-credentials.${name}.secret-key.service" ];
        }))
        vhosts;
    }

    (lib.mkIf cfg.enable {
      # Firewall
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      # nginx generic configuration
      services.nginx = {
        enable = true;
        package = pkgs.luffy.nginx;

        # Use the MIME types from mailcap, with a few adjustments.
        defaultMimeTypes = pkgs.runCommand "nginx-mime.types" { } ''
          sed -e "/^text\/vnd.trolltech.linguist[ \t]/d" \
              -e "1a video/mp2t      ts;" \
              ${pkgs.mailcap}/etc/nginx/mime.types > $out
        '';
        typesHashMaxSize = 2688;

        recommendedGzipSettings = true;
        recommendedBrotliSettings = true;
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

        resolver.addresses = [ "127.0.0.53" ];

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
        appendHttpConfig = ''
          # Default charset
          charset utf-8;
          charset_types
            application/atom+xml
            application/json
            application/rss+xml
            application/xml
            application/xslt+xml
            image/svg+xml
            text/css
            text/javascript
            text/plain
            text/vcard
            text/vtt
            text/xml;

          map $http_accept $webp_suffix {
            default        "";
            "~image/webp"  ".webp";
          }
          map $http_accept $avif_suffix {
            default        "";
            "~image/avif"  ".avif";
          }

          proxy_headers_hash_max_size 1024;
          proxy_headers_hash_bucket_size 128;
        '';
      };

      # Reload/restart logic. This could be enhanced once we have
      # https://github.com/systemd/systemd/issues/13284
      services.nginx.enableReload = true;
      systemd.services.nginx = {
        serviceConfig = {
          KillSignal = "QUIT";
          TimeoutStopSec = "120s";
          LogsDirectoryMode = lib.mkForce "0755";
        };
        # Do not make nginx wait for ACME certificates, even those not requiring
        # nginx. On unattended boot, we may not have the secrets to refresh them
        # while the certificates we have are still valid. See https://github.com/NixOS/nixpkgs/pull/336412
        after =
          let
            vhostsConfigs = lib.mapAttrsToList
              (vhostName: vhostConfig: vhostConfig // { certName = vhostName; })
              vhosts;
            acmeEnabledVhosts = lib.filter
              (vhostConfig: vhostConfig.enableACME)
              vhostsConfigs;
            vhostCertNames = lib.unique (map (hostOpts: hostOpts.certName) acmeEnabledVhosts);
          in
          lib.mkForce
            ([ "network.target" ] ++ map (certName: "acme-selfsigned-${certName}.service") vhostCertNames);
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
          nginxRoots = lib.mapAttrsToList (_: vhost: vhost.root) vhosts;
        in
        ''
          for d in ${builtins.concatStringsSep " " (map lib.escapeShellArg nginxRoots)}; do
            mkdir -p "$d"
            chown bernat:nginx "$d"
          done
        '';
    })
  ];
}
