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
    root = "/data/webserver/goatcounter.luffy.cx";
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      access_log /var/log/nginx/goatcounter.luffy.cx.log anonymous;
    '';
    locations = {
      "/" = {
        proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
      };
      "= /count".extraConfig = ''
        return 404;
      '';
    };
  };
  security.acme.certs."goatcounter.luffy.cx" = { };
}
