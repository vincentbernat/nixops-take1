{ lib, fetchFromGitHub, fetchurl, nginxStable, nginxModules, pcre2, ... }:

(nginxStable.override {
  # No stream module
  withStream = false;
  pcre2 = pcre2.override {
    withJitSealloc = false; # avoid crashes
  };
  modules = with nginxModules; [
    brotli
    ipscrub
  ];
}).overrideAttrs (old:
  let
    version = "1.30.6";
  in
  lib.throwIf (lib.versionOlder version old.version)
    "nginx is pinned to ${version} but nixpkgs has ${old.version}"
    {
      inherit version;
      src = fetchurl {
        url = "https://nginx.org/download/nginx-${version}.tar.gz";
        hash = "sha256-PPRvXtdQTUYBJYZre+qZ+zV/MdiH4uY7NVAzEOm4tsg=";
      };
      # See https://github.com/NixOS/nixpkgs/issues/182935
      disallowedReferences = [ ];
    })
