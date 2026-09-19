{ config, lib, ... }:
let
  cors = ''
    add_header Access-Control-Allow-Origin *;
  '';
  sts = ''
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";'';
  stsWithPreload = ''
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";'';
  httpOverSSH = builtins.elem "http-over-ssh" config.luffy.host.tags;
  redirectVhost = to: {
    addSSL = true;
    globalRedirect = to;
    useACMEHost = to;
    extraConfig = sts;
  };
  redirectBlogVhost = (redirectVhost "vincent.bernat.ch") // {
    extraConfig = sts;
  };
  mediaVhost = {
    forceSSL = true;
    extraConfig = ''
      expires 30d;
      ${cors}
      ${sts}
    '';
    # The following resources are expected to use cache busting.
    locations."/js".extraConfig = ''
      expires     max;
      add_header  Cache-Control immutable;
      ${cors}
      ${sts}
    '';
    locations."/css".extraConfig = ''
      expires     max;
      add_header  Cache-Control immutable;
      ${cors}
      ${sts}
    '';
    locations."/fonts".extraConfig = ''
      expires     max;
      add_header  Cache-Control immutable;
      ${cors}
      ${sts}
      types {
        application/font-woff         woff;
        font/woff2                    woff2;
        application/x-font-truetype   ttf;
      }
    '';
    locations."/files".extraConfig = "expires 1d;";
    locations."/videos".extraConfig = ''
      expires 1d;
      ${cors}
      ${sts}
    '';
    locations."/images".extraConfig = ''
      ${cors}
      ${sts}
    '';
    locations."~ ^/images/.*\\.(png|jpe?g|gif)$".extraConfig = ''
      ${cors}
      ${sts}
      add_header Vary Accept;
      try_files $uri$avif_suffix$webp_suffix $uri$avif_suffix $uri$webp_suffix $uri =404;
    '';
  };
in
{
  luffy.nginx.enable = true;

  luffy.goatcounter.proxy = {
    enable = true;
    site = "goatcounter.luffy.cx";
    listenAddress = "127.0.0.3";
    port = 8087;
  };

  services.nginx.virtualHosts = {
    # HAProxy
    "haproxy.debian.net" = {
      # Make dists and pool available without encryption
      addSSL = true;
      locations."~ ^/(dists|pool)".extraConfig = ''
        autoindex on;
      '';
      locations."/".extraConfig = ''
        if ($scheme = http) {
          # Safe usage of if-in-location
          return 301 https://$host$request_uri;
        }
      '';
    };

    # Le val insolite
    "le-val-insolite.fr" = redirectVhost "www.le-val-insolite.fr";
    "www.le-val-insolite.fr" = {
      forceSSL = true;
      extraConfig = sts;
    };

    # *.pages.luffy.cx
    "pages.luffy.cx" = {
      forceSSL = true;
    };
    "*.pages.luffy.cx" = {
      forceSSL = true;
      serverName = "~^(.*)\.pages\.luffy\.cx$";
      root = "/data/webserver/pages.luffy.cx/$1";
      useACMEHost = "pages.luffy.cx";
    };

    # Une Oasis Une École
    "une-oasis-une-ecole.fr" = redirectVhost "www.une-oasis-une-ecole.fr";
    "www.une-oasis-une-ecole.fr" = {
      forceSSL = true;
      extraConfig = ''
        include /data/webserver/www.une-oasis-une-ecole.fr/nginx*.conf;
        ${sts}
      '';
    };
    "media.une-oasis-une-ecole.fr" = mediaVhost // { useACMEHost = "www.une-oasis-une-ecole.fr"; };

    # ENXIO
    "enx.io" = redirectVhost "www.enxio.fr";
    "enxio.fr" = redirectVhost "www.enxio.fr";
    "www.enx.io" = redirectVhost "www.enxio.fr";
    "www.enxio.fr" = {
      forceSSL = true;
      extraConfig = ''
        include /data/webserver/www.enxio.fr/nginx*.conf;
        ${sts}
      '';
    };
    "media.enxio.fr" = mediaVhost // { useACMEHost = "www.enxio.fr"; };

    # Old website
    "luffy.cx" = {
      addSSL = true;
      globalRedirect = "www.luffy.cx";
      extraConfig = sts;
    };
    "www.luffy.cx" = {
      forceSSL = true;
      extraConfig = sts;
      useACMEHost = "luffy.cx";
      locations."/wiremaps".extraConfig = ''
        rewrite ^ https://github.com/vincentbernat/wiremaps permanent;
      '';
      locations."/udpproxy".extraConfig = ''
        rewrite ^ https://github.com/vincentbernat/udpproxy permanent;
      '';
      locations."/snimpy".extraConfig = ''
        rewrite ^ https://github.com/vincentbernat/snimpy permanent;
      '';
      locations."/lldpd".extraConfig = ''
        rewrite ^ https://lldpd.github.io permanent;
      '';
      locations."/".extraConfig = ''
        rewrite ^ https://vincent.bernat.ch$request_uri permanent;
      '';
    };

    # vincentbernat.com
    "vincentbernat.com" = {
      addSSL = true;
      globalRedirect = "vincent.bernat.ch";
    };
    "www.vincentbernat.com" = {
      addSSL = true;
      globalRedirect = "vincent.bernat.ch";
      useACMEHost = "vincentbernat.com";
    };

    # Blog
    "vincent.bernat.ch" = {
      forceSSL = true;
      extraConfig = ''
        include /data/webserver/vincent.bernat.ch/nginx*.conf;
      '';
      # Bluesky
      locations."= /.well-known/atproto-did".extraConfig = ''
        default_type text/plain;
        return 200 'did:plc:kb6tyjomr47ndk2rq4daooln';
      '';
    };
    "vincent.bernat.im" = redirectBlogVhost;
    "bernat.im" = redirectBlogVhost;
    "bernat.ch" = {
      forceSSL = true;
      useACMEHost = "vincent.bernat.ch";
      extraConfig = stsWithPreload;
      # Mastodon
      locations."= /.well-known/webfinger".extraConfig = ''
        if ($arg_resource = acct:vincent@bernat.ch) {
          return 302 https://hachyderm.io/.well-known/webfinger?resource=acct:vbernat@hachyderm.io;
        }
        return 404;
      '';
      locations."= /@vincent".extraConfig = ''
        return 302 https://hachyderm.io/@vbernat;
      '';
      # Use that instead of globalRedirect as it will only takes effect for
      # HTTPS. This is needed for HSTS.
      locations."/".extraConfig = ''
        return 301 https://vincent.bernat.ch$request_uri;
      '';
    };
    "media.bernat.ch" = mediaVhost // { useACMEHost = "vincent.bernat.ch"; };
    "media.luffy.cx" = mediaVhost // { useACMEHost = "luffy.cx"; };
  } // lib.optionalAttrs httpOverSSH {
    # *.ssh.luffy.cx
    "ssh.luffy.cx" = {
      forceSSL = true;
    };
    "*.ssh.luffy.cx" = {
      forceSSL = true;
      serverName = "~^p(?<port>\\d{4,5})\\.ssh\\.luffy\\.cx$";
      useACMEHost = "ssh.luffy.cx";
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:$port";
          extraConfig = ''
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header Host $host;
          '';
        };
      };
    };
  };
}
