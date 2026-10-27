# HTTP over SSH. Example of use:
#
#     Host http-over-ssh
#       Hostname web02.luffy.cx
#       RemoteCommand http-over-ssh
#       ControlPath none

{ config, pkgs, lib, ... }:
let
  httpOverSSHToken = builtins.toFile "compile-http-over-ssh.token" ''
    source <(pass show personal/nixops/secrets)
    printf '%s\n' "$HTTPSSH_SECRET"
  '';
  httpOverSSH = pkgs.writeShellApplication {
    name = "http-over-ssh";
    runtimeInputs = with pkgs; [ coreutils gawk iproute2 procps luffy.http-over-ssh-auth ];
    # Unfortunately, we need sudo as sshd-session dropped privileges and is not
    # observable by us.
    text = builtins.readFile ./http-over-ssh.sh;
  };
  authSocket = "/run/http-over-ssh-auth.sock";
in
{
  environment.systemPackages = [ httpOverSSH ];

  luffy.caddy.enable = true;
  services.caddy.virtualHosts = {
    "ssh.luffy.cx".luffy.static = true;
    "*.ssh.luffy.cx".extraConfig = ''
      @tunnel vars_regexp tunnel {host} `(?i)^h[0-9a-f]{24}-p(\d{1,5})\.ssh\.luffy\.cx$`
      handle @tunnel {
        forward_auth unix/${authSocket} {
          uri /{labels.3}
        }
        reverse_proxy 127.0.0.1:{re.tunnel.1} {
          flush_interval -1
          transport http {
            read_timeout 30m
          }
        }
      }
      respond 404
    '';
  };

  # Check tokens for Caddy
  systemd.sockets.http-over-ssh-auth = {
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = authSocket;
      SocketGroup = config.services.caddy.group;
      SocketMode = "0660";
    };
  };
  systemd.services.http-over-ssh-auth = {
    # Only the closure of ExecStart is visible
    confinement = {
      enable = true;
      binSh = null;
    };
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.luffy.http-over-ssh-auth} serve";

      # Temporary user, only this user can read the secret
      DynamicUser = true;
      LoadCredential = "secret:/var/keys/http-over-ssh.token";
      UMask = "0077";

      # Only the socket from systemd is usable
      PrivateNetwork = true;
      RestrictAddressFamilies = "none";
      IPAddressDeny = "any";

      # No privileges, and no way to get them
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;

      # Read-only files, and no view of other processes or devices
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      PrivateIPC = true;
      DevicePolicy = "closed";

      # No changes to the kernel or the system state
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelLogs = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;

      # Syscall filtering
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" "~@privileged @resources" ];
      SystemCallErrorNumber = "EPERM";
    };
  };

  deployment.keys = {
    "http-over-ssh.token" = {
      group = "wheel";
      permissions = "0640";
      destDir = "/var/keys";
      keyCommand = [ "${pkgs.runtimeShell}" "${httpOverSSHToken}" ];
    };
  };
}
