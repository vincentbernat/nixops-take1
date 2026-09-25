{ config, ... }:
let
  cfg = config.luffy.goatcounter.serve;
in
{
  luffy.goatcounter.serve = {
    enable = true;
    listenAddress = "127.0.0.4";
    port = 8088;
  };
  luffy.litestream.databases.goatcounter = cfg.databaseFile;

  # Nginx vhost
  services.nginx.virtualHosts."goatcounter.luffy.cx" = {
    forceSSL = true;
    luffy.acmeDNS = false;
    locations = {
      "/" = {
        proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
      };
      "= /count".extraConfig = ''
        return 404;
      '';
    };
  };
}
