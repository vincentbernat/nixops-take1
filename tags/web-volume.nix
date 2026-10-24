# Sites needing a lot of disk space.
let
  mediaVhost = {
    luffy.static = true;
    luffy.strictTransportSecurity = true;
    extraConfig = "import media";
  };
in
{
  luffy.caddy.enable = true;

  services.caddy.extraConfig = ''
    (media) {
      header {
        Access-Control-Allow-Origin *
        ?Cache-Control max-age=2592000
      }
      # The following resources are expected to use cache busting.
      header /js/* Cache-Control "max-age=31536000, immutable"
      header /css/* Cache-Control "max-age=31536000, immutable"
      header /fonts/* Cache-Control "max-age=31536000, immutable"
      header /files/* Cache-Control max-age=86400
      header /videos/* Cache-Control max-age=86400

      map {header.Accept} {avif} {
        ~image/avif .avif
      }
      map {header.Accept} {webp} {
        ~image/webp .webp
      }
      @alternative {
        path_regexp ^/images/.*\.(png|jpe?g|gif)$
        file {path}{avif}{webp} {path}{avif} {path}{webp}
      }
      header @alternative Vary Accept
      rewrite @alternative {file_match.relative}
    }
  '';

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

    "media.une-oasis-une-ecole.fr" = mediaVhost;
    "media.enxio.fr" = mediaVhost;
    "media.bernat.ch" = mediaVhost;
  };
}
