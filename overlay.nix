self: super:
{
  mailcap = super.mailcap.override {
    fetchzip = { ... } @ args:
      super.fetchzip ({
        sha256 = "1ah9jz80md2w4livm4qnc08haym6aib82mi9dy2hacs9ng2j2mqd";
        postFetch = ''
          ${args.postFetch}
          sed -i -e "/^application\/javascript /d" \
                 -e "1a text/javascript js;" \
                 -e "1a text/vtt        vtt;" \
              $out/etc/nginx/mime.types
        '';
      } // removeAttrs args [ "postFetch" "sha256" ]);
  };
}
