{ config, pkgs, lib, nodes, ... }:
let
  secrets = (import ./secrets.nix).isso;
  # Isso configuration file
  # Backup of sqlite can be done with:
  #   nix run nixpkgs.sqlite --command sudo sqlite3 /var/db/isso/comments.db .dump \
  #   | gzip -c > comments-isso-$(date -I).txt.gz
  issoConfig = pkgs.writeText "isso.conf" ''
[general]
dbpath = /db/comments.db
host =
  https://vincent.bernat.ch
  http://localhost:8080
notify = smtp
reply-notifications = true
max-age = 1s

[moderation]
enabled = true
purge-after = 120d

[server]
public-endpoint = https://comments.luffy.cx

[smtp]
host = smtp.fastmail.com
username = vincent@bernat.ch
port = 587
security = starttls
password = ${secrets.smtp-password}
to = isso@vincent.bernat.ch
from = isso@vincent.bernat.ch

[markup]
options = autolink,fenced-code
allowed-elements = a,blockquote,br,code,del,em,ins,li,ol,p,pre,strong,ul
allowed-attributes = href

[hash]
salt = ${secrets.salt}
        '';
  issoPort = 8080;
  # Custom derivation for Isso, as the one in NixOS is a PythonApp
  # instead of a PythonPackage and cannot be imported with buildEnv.
  issoPackage = with pkgs.python3Packages; buildPythonPackage rec {
    pname = "isso";
    version = "custom";

    src = pkgs.fetchFromGitHub {
      owner = "vincentbernat";
      repo = pname;
      rev = "vbe/master";
      sha256 = "14q2w6q1zh6j6a24zj2rsyrlgdp6qbixk3jy5cmslld3gq9v1j6w";
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

    checkInputs = [ nose ];

    checkPhase = ''
      ${python.interpreter} setup.py nosetests
    '';
  };
  # Python environment to use, containing isso and gunicorn
  issoEnv = pkgs.python3.buildEnv.override {
      extraLibs = [
        issoPackage
        pkgs.python3Packages.gunicorn
        pkgs.python3Packages.gevent
      ];
  };
  issoDockerImage = pkgs.dockerTools.buildImage {
    name = "isso";
    tag = "latest";
    extraCommands = ''
      mkdir -p db
    '';
    config = {
      Cmd = [ "${issoEnv}/bin/gunicorn"
              "--name" "isso"
              "--bind" "0.0.0.0:${toString issoPort}"
              "--worker-class" "gevent"
              "--workers" "2"
              "--worker-tmp-dir" "/dev/shm"
              "--preload"
              "isso.run"
            ];
      Env = [
        "ISSO_SETTINGS=${issoConfig}"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
    };
  };
in {
  # Container
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      isso = {
        image = "isso";
        imageFile = issoDockerImage;
        ports = ["127.0.0.1:${toString issoPort}:${toString issoPort}"];
        volumes = [
          "/var/db/isso:/db"
        ];
      };
    };
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
      proxyPass = "http://127.0.0.1:${toString issoPort}";
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
  security.acme.certs."comments.luffy.cx" = {
  };
}
