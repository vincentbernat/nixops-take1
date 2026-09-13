{ config, ... }:
let
  cfg = config.luffy.isso;
  issoMkConfig = builtins.toFile "isso-mkconf" ''
    source <(pass show personal/nixops/secrets)

    cat <<EOF
    [general]
    dbpath = ${cfg.databaseFile}
    host =
      https://vincent.bernat.ch
      http://localhost:8080
    notify = smtp
    reply-notifications = true
    max-age = 1s

    [moderation]
    enabled = true
    purge-after = 120d
    approve-if-email-previously-approved = true

    [server]
    public-endpoint = https://comments.luffy.cx

    [smtp]
    host = smtp.fastmail.com
    username = vincent@bernat.ch
    port = 587
    security = starttls
    password = $ISSO_SMTP_PASSWORD
    to = isso@vincent.bernat.ch
    from = isso@vincent.bernat.ch

    [markup]
    renderer = mistune
    allowed-elements = a,blockquote,br,code,del,em,ins,li,ol,p,pre,strong,ul,kbd
    allowed-attributes = href

    [hash]
    salt = $ISSO_SALT
    EOF
  '';
in
{
  luffy.isso = {
    enable = true;
    listenAddress = "127.0.0.2";
    port = 8086;
    configScript = issoMkConfig;
  };
  luffy.litestream.databases.isso = cfg.databaseFile;

  # Nginx vhost
  services.nginx.virtualHosts."comments.luffy.cx" = {
    root = "/data/webserver/comments.luffy.cx";
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      access_log /var/log/nginx/comments.luffy.cx.log anonymous;
    '';
    locations."/" = {
      proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
      extraConfig = ''
        proxy_hide_header Set-Cookie;
        proxy_hide_header X-Set-Cookie;
        proxy_ignore_headers Set-Cookie;
        add_header Strict-Transport-Security "max-age=31536000" always;
      '';
    };
  };
  security.acme.certs."comments.luffy.cx" = { };
}
