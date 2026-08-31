{ lib, fetchFromGitHub, nginxStable, nginxModules, pcre2, ... }:

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
}).overrideAttrs (old: {
  # See https://github.com/NixOS/nixpkgs/issues/182935
  disallowedReferences = [ ];
})
