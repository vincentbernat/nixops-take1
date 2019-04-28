{ config, pkgs, lib, nodes, ... }:
{
  networking.firewall.allowedTCPPorts = [ 80 443 7667 ];

  services.znc = {
    enable = true;
    group = config.services.znc.user;

    # ZNC configuration can be modified by the user or from the admin
    # interface. It makes little sense to provide a complete
    # configuration here.
    mutable = true;
    configFile = pkgs.writeText "znc.conf" ''
        # To be put manually.
    '';
  };

  # Handle certificate
  services.nginx = {
    enable = true;
    recommendedOptimisation  = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;
    virtualHosts."znc.luffy.cx" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "https://127.0.0.1:7667/";
    };
  };
  security.acme = {
    certs."znc.luffy.cx" = {
      email = lib.concatStringsSep "@" ["letsencrypt" "vincent.bernat.ch"];
      postRun =
        ''
          cat full.pem > ${config.services.znc.dataDir}/znc.pem
          chown ${config.services.znc.user}:${config.services.znc.group} ${config.services.znc.dataDir}/znc.pem
          chmod 0550 ${config.services.znc.dataDir}/znc.pem
          systemctl reload znc
        '';
    };
  };
}
