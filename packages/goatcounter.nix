{ lib, goatcounter, fetchFromGitHub }:

goatcounter.overrideAttrs (old: {
  src = fetchFromGitHub {
    owner = "vincentbernat";
    repo = "goatcounter";
    rev = "feature/proxy";
    hash = "sha256-0BzyhT599bzwLXaLKX6W5tczpZ+Tcj8is73VxLiheGY=";
  };
  vendorHash = "sha256-c9Q5OrbZR+q6pD3SgPPWe8JUzcZco1AVUKGaV61k5DE=";
})
