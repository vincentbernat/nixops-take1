# HTTP over SSH. Example of use:
#
#     Host http-over-ssh
#       Hostname web02.luffy.cx
#       RemoteCommand http-over-ssh
#       ControlPath none

{ pkgs, ... }:
let
  httpOverSSHSecret = builtins.toFile "compile-http-over-ssh.secret" ''
    source <(pass show personal/nixops/secrets)
    printf 'secure_link_md5 "$secure_link_expires $port %s";\n' "$HTTPSSH_SECRET"
  '';
  httpOverSSHToken = builtins.toFile "compile-http-over-ssh.token" ''
    source <(pass show personal/nixops/secrets)
    printf '%s\n' "$HTTPSSH_SECRET"
  '';
  httpOverSSH = pkgs.writeShellApplication {
    name = "http-over-ssh";
    runtimeInputs = with pkgs; [ coreutils gawk iproute2 openssl procps ];
    # Unfortunately, we need sudo as sshd-session dropped privileges and is not
    # observable by us.
    text = builtins.readFile ./http-over-ssh.sh;
  };
in
{
  environment.systemPackages = [ httpOverSSH ];

  luffy.nginx.enable = true;
  services.nginx.appendHttpConfig = ''
    map $remote_user $httpssh_link {
      "~^([-_A-Za-z0-9]{22})--([0-9]+)$" "$1,$2";
    }
  '';
  services.nginx.virtualHosts = {
    "ssh.luffy.cx" = {
      forceSSL = true;
    };
    "*.ssh.luffy.cx" = {
      forceSSL = true;
      serverName = "~^p(?<port>\\d\\d\\d\\d\\d)\\.ssh\\.luffy\\.cx$";
      useACMEHost = "ssh.luffy.cx";
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:$port";
          proxyWebsockets = true;
          extraConfig = ''
            secure_link $httpssh_link;
            include /var/keys/http-over-ssh.secret;
            if ($secure_link = "") {
              add_header WWW-Authenticate 'Basic realm="tunnel"' always;
              return 401;
            }
            if ($secure_link = "0") {
              return 410;
            }
            proxy_set_header Authorization "";
            proxy_buffering off;
            proxy_read_timeout 30m;
          '';
        };
      };
    };
  };

  deployment.keys = {
    "http-over-ssh.secret" = {
      group = "nginx";
      permissions = "0640";
      destDir = "/var/keys";
      keyCommand = [ "${pkgs.runtimeShell}" "${httpOverSSHSecret}" ];
    };
    "http-over-ssh.token" = {
      group = "wheel";
      permissions = "0640";
      destDir = "/var/keys";
      keyCommand = [ "${pkgs.runtimeShell}" "${httpOverSSHToken}" ];
    };
  };
}
