{ lib, fetchFromGitHub, nginxStable, nginxModules, pcre2, ... }:

(nginxStable.override {
  # No stream module
  withStream = false;
  pcre2 = pcre2.override {
    withJitSealloc = false; # avoid crashes
  };
  modules =
    let
      acceptlanguage = {
        name = "accept-language";
        src = fetchFromGitHub {
          name = "accept-language";
          owner = "giom";
          repo = "nginx_accept_language_module";
          rev = "2f69842f83dac77f7d98b41a2b31b13b87aeaba7";
          hash = "sha256-fMENKki03aQmw2rX8gMmdwnGUBL4qsPHEAXOEmjWXsI=";
        };
        meta = with lib; {
          description = "Parse Accept-Language header";
          homepage = "https://github.com/giom/nginx_accept_language_module";
          license = with licenses; [ bsd2 ];
          maintainers = with maintainers; [ ];
        };
      };
    in
    with nginxModules; [
      brotli
      ipscrub
      acceptlanguage
    ];
}).overrideAttrs (old: {
  # See https://github.com/NixOS/nixpkgs/issues/182935
  disallowedReferences = [ ];
})
