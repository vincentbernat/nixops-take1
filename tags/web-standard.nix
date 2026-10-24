let
  redirectVhost = to: {
    luffy.http = true;
    luffy.strictTransportSecurity = true;
    extraConfig = "redir https://${to}{uri} 301";
  };
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

  luffy.goatcounter.proxy = {
    enable = true;
    site = "goatcounter.luffy.cx";
    listenAddress = "127.0.0.3";
    port = 8087;
  };

  services.caddy.virtualHosts = {
    # Le val insolite
    "le-val-insolite.fr" = redirectVhost "www.le-val-insolite.fr";
    "www.le-val-insolite.fr" = {
      luffy.static = true;
      luffy.strictTransportSecurity = true;
    };

    # *.pages.luffy.cx
    "pages.luffy.cx".luffy.static = true;
    "*.pages.luffy.cx".extraConfig = ''
      root * /data/webserver/pages.luffy.cx/{labels.3}
      file_server
    '';

    # Une Oasis Une École
    "une-oasis-une-ecole.fr" = redirectVhost "www.une-oasis-une-ecole.fr";
    "www.une-oasis-une-ecole.fr" = {
      luffy.static = true;
      luffy.siteConfig = true;
      luffy.strictTransportSecurity = true;
    };
    "media.une-oasis-une-ecole.fr" = mediaVhost;

    # ENXIO
    "enx.io" = redirectVhost "www.enxio.fr";
    "enxio.fr" = redirectVhost "www.enxio.fr";
    "www.enx.io" = redirectVhost "www.enxio.fr";
    "www.enxio.fr" = {
      luffy.static = true;
      luffy.strictTransportSecurity = true;
      extraConfig = ''
        handle_errors 403 404 {
          rewrite * /
          file_server {
            status {err.status_code}
          }
        }
      '';
    };
    "media.enxio.fr" = mediaVhost;

    # Old website
    "luffy.cx" = redirectVhost "www.luffy.cx";
    "www.luffy.cx" = {
      luffy.strictTransportSecurity = true;
      extraConfig = ''
        redir /wiremaps* https://github.com/vincentbernat/wiremaps 301
        redir /udpproxy* https://github.com/vincentbernat/udpproxy 301
        redir /snimpy* https://github.com/vincentbernat/snimpy 301
        redir /lldpd* https://lldpd.github.io 301
        redir https://vincent.bernat.ch{uri} 301
      '';
    };

    # Blog
    "vincentbernat.com" = redirectVhost "vincent.bernat.ch";
    "www.vincentbernat.com" = redirectVhost "vincent.bernat.ch";
    "vincent.bernat.im" = redirectVhost "vincent.bernat.ch";
    "bernat.im" = redirectVhost "vincent.bernat.ch";
    "vincent.bernat.ch" = {
      luffy.static = true;
      luffy.siteConfig = true;
      extraConfig = ''
        # Bluesky
        route /.well-known/atproto-did {
          header Content-Type text/plain
          respond did:plc:kb6tyjomr47ndk2rq4daooln
        }
      '';
    };
    "media.bernat.ch" = mediaVhost;
    "bernat.ch".luffy.strictTransportSecurity = "preload";
    "bernat.ch".extraConfig = ''
      # Mastodon
      @mastodon query resource=acct:vincent@bernat.ch
      handle /.well-known/webfinger {
        redir @mastodon https://hachyderm.io/.well-known/webfinger?resource=acct:vbernat@hachyderm.io 302
        respond 404
      }
      handle {
        redir /@vincent https://hachyderm.io/@vbernat 302
        redir https://vincent.bernat.ch{uri} 301
      }
    '';
  };
}
