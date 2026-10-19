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

  services.caddy.virtualHosts."goatcounter.luffy.cx" = {
    extraConfig = ''
      header Strict-Transport-Security "max-age=31536000"
      respond /count 404
      reverse_proxy ${cfg.listenAddress}:${toString cfg.port}
    '';
  };
}
