{ config, pkgs, lib, ... }:
let
  cfg = config.luffy.caddy;
  caddy = config.services.caddy;
  vhosts = caddy.virtualHosts;
  certificateDir = "/var/keys";
  certificateFile = cert: ext: "${certificateDir}/tls-${cert}.${ext}";
  tlsDirective = cert: "tls ${certificateFile cert "crt"} ${certificateFile cert "key"}";
  loggerName = name: lib.replaceStrings [ "*" "." ] [ "_" "_" ] name;
  logDirective = name: ''
    log ${loggerName name} {
      output file ${caddy.logDir}/${lib.replaceStrings [ "*" ] [ "_" ] name}.log {
        mode 0644
        roll_at 00:00
        roll_keep_for 30d
      }
      format filter {
        request>remote_ip ip_mask 16 32
        request>client_ip ip_mask 16 32
        request>headers>Cookie delete
        resp_headers delete
      }
    }
  '';
  fromLegoStateFile = builtins.toFile "from-lego-state-file" ''
    set -o pipefail
    pass show personal/nixops/tls/lego \
      | jq -je --arg path "$1" '.[$path] // error("\($path) is missing")'
  '';

  # One certificate for each top-level domain. For luffy.cx, one certificate for
  # each third-level name, with www sharing the certificate of the domain.
  certificateName = name:
    let
      labels = lib.splitString "." (lib.removePrefix "*." name);
      last = n: lib.drop (lib.max 0 (builtins.length labels - n)) labels;
      domain = last 2;
      third = last 3;
    in
    lib.concatStringsSep "."
      (if domain != [ "luffy" "cx" ] then domain
      else if builtins.head third == "www" then builtins.tail third
      else third);
in
{
  options.luffy.caddy.enable = lib.mkEnableOption "Caddy";

  options.luffy.caddy.certificates = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    readOnly = true;
    description = ''
      Names for each certificate. Certificates are requested "offline"
      with `nix run .#certificates`.
    '';
  };

  options.services.caddy.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
      options.luffy = {
        certificate = lib.mkOption {
          type = lib.types.str;
          default = certificateName name;
          description = "Name of the certificate containing this virtual host.";
        };
        http = lib.mkEnableOption "plain HTTP instead of a redirect to HTTPS";
        static = lib.mkEnableOption "serving files from /data/webserver/<name>";
      };
      config = {
        logFormat = null;
        extraConfig = lib.mkMerge [
          (lib.mkBefore (logDirective name + ''
            import common
            ${tlsDirective config.luffy.certificate}
          ''))
          (lib.mkIf config.luffy.static ''
            root * /data/webserver/${name}
            file_server
          '')
        ];
      };
    }));
  };

  config = lib.mkMerge [
    {
      # Sort certificates by length
      luffy.caddy.certificates = lib.mapAttrs
        (_:
          lib.sort
            (a: b: lib.stringLength a < lib.stringLength b || (lib.stringLength a == lib.stringLength b && a < b)))
        (lib.zipAttrs (lib.mapAttrsToList
          (name: vhost: { ${vhost.luffy.certificate} = name; })
          vhosts));
    }
    (lib.mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      services.caddy = {
        enable = true;
        globalConfig =
          # The admin API is only needed for reload. Only the caddy user can
          # access it.
          ''
            admin unix//run/caddy/admin.sock|0600
            persist_config off
          ''
          # No HTTP/3. From a security point of view, the additional code does
          # not look like a good trade-off.
          + ''
            servers {
              protocols h1 h2
            }
          ''
          # Certificates are not requested by Caddy.
          + ''
            auto_https disable_certs
          '';
        extraConfig = lib.mkMerge [
          ''
            (common) {
              encode zstd gzip
            }
          ''
          # Caddy does not accept a tls directive in a site block with an HTTP
          # address. Use a separate site block for HTTP, without it.
          (lib.mkAfter (lib.concatStrings (lib.mapAttrsToList
            (name: vhost: ''
              http://${name} {
                ${lib.replaceStrings
                  [
                    (logDirective name)
                    "${tlsDirective vhost.luffy.certificate}\n"
                  ] [
                    "log ${loggerName name}\n"
                    ""
                  ]
                  vhost.extraConfig
                }
              }
            '')
            (lib.filterAttrs (_: vhost: vhost.luffy.http) vhosts))))
        ];
      };

      # /etc/mime.types is used by Go for extensions it does not know.
      environment.etc."mime.types".source = "${pkgs.mailcap}/etc/mime.types";

      # Certificate management
      deployment.keys = lib.listToAttrs (lib.concatMap
        (cert: map
          ({ ext, permissions }: lib.nameValuePair "tls-${cert}.${ext}" {
            inherit permissions;
            user = caddy.user;
            group = caddy.group;
            destDir = certificateDir;
            keyCommand = [
              "${pkgs.runtimeShell}"
              "${fromLegoStateFile}"
              "certificates/${lib.replaceStrings [ "*" ] [ "_" ] (builtins.head cfg.certificates.${cert})}.${ext}"
            ];
          })
          [
            { ext = "crt"; permissions = "0444"; }
            { ext = "key"; permissions = "0400"; }
          ])
        (lib.attrNames cfg.certificates));
      # Reload Caddy when a certificate is uploaded.
      systemd.paths.caddy-certificates = {
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathChanged = lib.concatMap
          (cert: [ (certificateFile cert "crt") (certificateFile cert "key") ])
          (lib.attrNames cfg.certificates);
      };
      systemd.services.caddy.serviceConfig = {
        RuntimeDirectory = "caddy";
        RuntimeDirectoryMode = "0700";
      };
      systemd.services.caddy-certificates = {
        serviceConfig.Type = "oneshot";
        # Wait for all the keys to be uploaded.
        serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
        serviceConfig.ExecStart = "${config.systemd.package}/bin/systemctl try-reload-or-restart caddy.service";
      };

      system.checks = [
        (pkgs.runCommand "caddy-adapt" { } ''
          HOME=$TMPDIR ${lib.getExe caddy.package} adapt --config ${caddy.configFile} --adapter caddyfile > $out
        '')
      ];

      # Create root directories for vhost. They are not pure yet.
      system.activationScripts.caddyRoots =
        let
          roots = lib.mapAttrsToList (name: _: "/data/webserver/${name}")
            (lib.filterAttrs (_: vhost: vhost.luffy.static) vhosts);
        in
        lib.stringAfter [ "users" "groups" ] ''
          for d in ${lib.escapeShellArgs roots}; do
            [ -L "$d" ] && continue
            mkdir -p "$d"
            chown bernat:${caddy.group} "$d"
          done
        '';
    })
  ];
}
