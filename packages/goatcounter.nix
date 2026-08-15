{ lib, goatcounter, fetchFromGitHub }:

goatcounter.overrideAttrs (old: {
  src = fetchFromGitHub {
    owner = "vincentbernat";
    repo = "goatcounter";
    rev = "feature/proxy";
    hash = "sha256-dJRlQlFu3tjcEgabT1LEbyFrasJlhmYu4L/T7EkoNcY=";
  };
  vendorHash = "sha256-c9Q5OrbZR+q6pD3SgPPWe8JUzcZco1AVUKGaV61k5DE=";
})
