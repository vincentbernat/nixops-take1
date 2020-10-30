{ config, pkgs, lib, nodes, ... }:
let
  secrets = (import ./secrets.nix).isso;
  # Isso configuration file
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
  # Custom package for Isso, as the one in NixOS is currently broken
  issoPackage = with pkgs.python3Packages; buildPythonPackage rec {
    pname = "isso";
    version = "custom";

    src = pkgs.fetchFromGitHub {
      owner = "vincentbernat";
      repo = pname;
      rev = "vbe/master";
      sha256 = "0vkkvjcvcjcdzdj73qig32hqgjly8n3ln2djzmhshc04i6g9z07j";
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
in {
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      isso = {
        image = "isso";
        imageFile = pkgs.dockerTools.buildImage {
          name = "isso";
          tag = "latest";
          contents = [
            issoPackage
          ];
          runAsRoot = ''
            mkdir -p /db
          '';
          config = {
            Cmd = [ "${issoEnv}/bin/gunicorn"
                    "--name" "isso"
                    "--bind" "0.0.0.0:8080"
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
        ports = ["127.0.0.1:8080:8080"];
        volumes = [
          "/var/db/isso:/db"
        ];
      };
    };
  };
}
