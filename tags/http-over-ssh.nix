{ pkgs, ... }:
let
  httpOverSSHSecret = builtins.toFile "compile-http-over-ssh.secret" ''
    source <(pass show personal/nixops/secrets)
    printf 'secure_link_md5 "$secure_link_expires $port %s";\n' "$HTTPSSH_SECRET"
  '';
in
{
  services.nginx.virtualHosts = {
    "ssh.luffy.cx" = {
      forceSSL = true;
    };
    "*.ssh.luffy.cx" = {
      forceSSL = true;
      serverName = "~^p(?<port>\\d\\d\\d\\d\\d?)\\.ssh\\.luffy\\.cx$";
      useACMEHost = "ssh.luffy.cx";
      extraConfig = ''
        secure_link $cookie_httpssh;
        include /var/keys/http-over-ssh.secret;
      '';
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:$port";
          extraConfig = ''
            if ($request_uri ~ "^([^?]*)\?t=[-_A-Za-z0-9]+,[0-9]+$") {
              add_header Set-Cookie "httpssh=$arg_t; Path=/; Secure; HttpOnly; SameSite=Lax";
              return 302 $1;
            }
            if ($secure_link = "") {
              return 404;
            }
            if ($secure_link = "0") {
              return 410;
            }
          '';
        };
      };
    };
  };

  deployment.keys."http-over-ssh.secret" = {
    group = "nginx";
    permissions = "0640";
    destDir = "/var/keys";
    keyCommand = [ "${pkgs.runtimeShell}" "${httpOverSSHSecret}" ];
  };
}
