{ config, pkgs, lib, ... }:
let
  # Isso configuration file
  # Backup of sqlite can be done with:
  #   nix run nixpkgs.sqlite --command sudo sqlite3 /var/db/isso/comments.db .dump \
  #   | gzip -c > comments-isso-$(date -I).txt.gz
  issoMkConfig = builtins.toFile "isso-mkconf" ''
    source <(pass show personal/nixops/secrets)

    cat <<EOF
    [general]
    dbpath = /var/db/isso/comments.db
    host =
      https://vincent.bernat.ch
      http://localhost:8080
    notify = smtp
    reply-notifications = true
    max-age = 1s

    [moderation]
    enabled = true
    purge-after = 120d
    approve-if-email-previously-approved = true

    [server]
    public-endpoint = https://comments.luffy.cx

    [smtp]
    host = smtp.fastmail.com
    username = vincent@bernat.ch
    port = 587
    security = starttls
    password = $ISSO_SMTP_PASSWORD
    to = isso@vincent.bernat.ch
    from = isso@vincent.bernat.ch

    [markup]
    options = autolink,fenced-code
    allowed-elements = a,blockquote,br,code,del,em,ins,li,ol,p,pre,strong,ul,kbd
    allowed-attributes = href

    [hash]
    salt = $ISSO_SALT
    EOF
  '';
  issoPort = 8080;
  issoIP = "192.168.247.10";
  hostIP = "192.168.247.11";
  # Custom derivation for Isso, as the one in NixOS is a PythonApp
  # instead of a PythonPackage and cannot be imported with buildEnv.
  issoPackage = with pkgs.python3Packages; buildPythonPackage rec {
    pname = "isso";
    version = "custom";
    format = "setuptools";

    src = pkgs.fetchFromGitHub {
      owner = "vincentbernat";
      repo = pname;
      rev = "vbe/master";
      hash = "sha256-s4mM+jv3LDRoI3S8X+v2JdRltPivk8+NvkEyIItuOnM=";
    };

    propagatedBuildInputs = [
      itsdangerous
      jinja2
      misaka
      html5lib
      werkzeug
      bleach
      flask-caching
    ];
    buildInputs = [
      cffi
    ];
    checkInputs = [
      pytest
      pytest-cov
    ];
  };
  # Python environment to use, containing isso and gunicorn
  issoEnv = pkgs.python3.buildEnv.override {
    extraLibs = [
      issoPackage
      pkgs.python3Packages.gunicorn
      pkgs.python3Packages.gevent
    ];
  };
in
{
  # Systemd container
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-isso" ];
  };
  containers.isso = {
    ephemeral = true;
    autoStart = true;
    bindMounts."/var/db/isso" = {
      hostPath = "/var/db/isso";
      isReadOnly = false;
    };
    bindMounts."/etc/isso.cfg" = {
      hostPath = "/var/keys/isso.cfg";
      isReadOnly = true;
    };
    extraFlags = [ "--resolv-conf=bind-host" ];
    privateNetwork = true;
    hostAddress = "${hostIP}";
    localAddress = "${issoIP}";
    config = {
      networking.firewall.allowedTCPPorts = [ issoPort ];
      system.stateVersion = config.system.stateVersion;
      systemd.services.console-getty.enable = false;
      systemd.services.isso = {
        description = "Isso commenting server";
        wantedBy = [ "multi-user.target" ];
        script = ''
          ${issoEnv}/bin/gunicorn \
            --name isso \
            --bind ${issoIP}:${toString issoPort} \
            --worker-class gevent --workers 2 --worker-tmp-dir /dev/shm \
            --preload isso.run
        '';
        environment = {
          ISSO_SETTINGS = "/etc/isso.cfg";
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };
        serviceConfig = {
          SupplementaryGroups = [ "keys" ];
          DynamicUser = true;
          StateDirectory = "isso";
          Restart = "always";
          ExecStartPre = "+${pkgs.coreutils}/bin/chown -R isso:isso /var/db/isso";
          ExecStopPost = "+${pkgs.coreutils}/bin/chown -R nobody:nogroup /var/db/isso";
          ReadWritePaths = "/var/db/isso";
        };
      };
    };
  };
  deployment.keys."isso.cfg" = {
    group = "keys";
    permissions = "0640";
    destDir = "/var/keys";
    keyCommand = [ "${pkgs.runtimeShell}" "${issoMkConfig}" ];
  };
  systemd.services."container@isso" = {
    requires = [ "isso.cfg-key.service" ];
    after = [ "isso.cfg-key.service" ];
  };

  # Nginx vhost
  services.nginx.virtualHosts."comments.luffy.cx" = {
    root = "/data/webserver/comments.luffy.cx";
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      access_log /var/log/nginx/comments.luffy.cx.log anonymous;
    '';
    locations."/" = {
      proxyPass = "http://${issoIP}:${toString issoPort}";
      extraConfig = ''
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_hide_header Set-Cookie;
        proxy_hide_header X-Set-Cookie;
        proxy_ignore_headers Set-Cookie;
        add_header Strict-Transport-Security "max-age=31536000" always;
      '';
    };
  };
  security.acme.certs."comments.luffy.cx" = { };
}
