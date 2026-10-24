# Sites needing a lot of disk space.
{
  luffy.caddy.enable = true;

  services.caddy.virtualHosts = {
    # HAProxy
    "haproxy.debian.net" = {
      luffy.certificate = "haproxy.debian.net";
      # Make dists and pool available without encryption
      luffy.http = true;
      luffy.static = true;
      extraConfig = ''
        @repository path /dists* /pool*
        @insecure {
          protocol http
          not path /dists* /pool*
        }
        redir @insecure https://{host}{uri} 301
        file_server @repository browse
      '';
    };
  };
}
