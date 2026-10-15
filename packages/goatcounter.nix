{ lib, goatcounter, fetchFromGitHub }:

goatcounter.overrideAttrs (_: {
  src = fetchFromGitHub {
    owner = "vincentbernat";
    repo = "goatcounter";
    rev = "vbe/main";
    hash = "sha256-yzllD1bq3bl/UOKWdJReeaUoQ/Vg/wDwZuWqAkc8NGw=";
  };
  vendorHash = "sha256-c9Q5OrbZR+q6pD3SgPPWe8JUzcZco1AVUKGaV61k5DE=";
})
