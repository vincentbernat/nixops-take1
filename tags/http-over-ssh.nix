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
    text = ''
      days=''${1:-1}
      lifetime=$(( days * 86400 ))

      # Find ancestor sshd-session processes (OpenSSH 9.8+)
      pids=$(
        pid=$$
        while [ "$pid" -gt 1 ]; do
          line=$(ps -o comm=,pid=,ppid= -p "$pid")
          echo "$line"
          pid=''${line##* }
        done | awk '$1 == "sshd-session" { printf "pid=%s,\n", $2 }'
      )
      if [ -z "$pids" ]; then
        echo "not an ssh session" >&2
        exit 1
      fi

      secret=$(cat /var/keys/http-over-ssh.token)

      while :; do
        # Find ports allocated to sshd-session
        ports=$(sudo -n ss --listening --numeric --tcp --processes --no-header \
                  | grep -F "$pids" \
                  | awk '{ print $4 }' | awk -F: '{ print $NF }' \
                  | sort -un)
        if [ -z "$ports" ]; then
          echo "no forwarded port, use ssh -R 0:localhost:PORT" >&2
          exit 1
        fi

        # For each port, print the URL with token and expiry
        expires=$(( $(date +%s) + lifetime ))
        while read -r port; do
          token=$(printf '%s %s %s' "$expires" "$port" "$secret" \
                    | openssl md5 -binary \
                    | openssl base64 \
                    | tr +/ -_ | tr -d =)
          echo "https://p$port.ssh.luffy.cx/t=$token,$expires/"
        done <<< "$ports"

        sleep $(( lifetime / 2 ))
      done
    '';
  };
in
{
  environment.systemPackages = [ httpOverSSH ];

  luffy.nginx.enable = true;
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
            if ($request_uri ~ "^/t=([-_A-Za-z0-9]{22},[0-9]+)(/.*)$") {
              add_header Set-Cookie "httpssh=$1; Path=/; Secure; HttpOnly; SameSite=Lax";
              return 302 $2;
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
