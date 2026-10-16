{ config, pkgs, lib, ... }:
let
  nameservers = lib.unique ([ config.networking.fqdn ] ++ map (s: s.name)
    (builtins.filter (s: builtins.elem "dns" s.tags) (lib.importJSON ../cdktf.json).servers.value));
  pass = entry: [ "${pkgs.runtimeShell}" "-c" "pass show ${entry}" ];
  zone = name: tsigKeys: {
    zoneFile = pkgs.writeText "${name}.zone" ''
      $ORIGIN ${name}.
      $TTL 3600
      @ IN SOA ${config.networking.fqdn}. hostmaster.luffy.cx. (
        1      ; serial
        3600   ; refresh
        600    ; retry
        604800 ; expire
        300    ; negative TTL
      )
      ${lib.concatMapStrings (ns: "@ IN NS ${ns}.\n") nameservers}
    '';
    # openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
    #   | pass insert -m personal/nixops/dns/ZONE/dnssec
    # DS record for the parent zone:
    # echo "ZONE. 3600 IN DNSKEY 257 3 13 $(pass show personal/nixops/dns/ZONE/dnssec \
    #   | openssl pkey -pubout -outform DER | tail -c 64 | base64 -w0)" \
    #   | dnssec-dsfromkey -a SHA-256 -f - ZONE
    dnssecKey = pass "personal/nixops/dns/${name}/dnssec";
    # openssl rand -base64 32 | pass insert -m personal/nixops/dns/ZONE/tsig/KEY
    tsigKeys = lib.genAttrs tsigKeys (key: [
      "${pkgs.runtimeShell}"
      "-c"
      "pass show personal/nixops/dns/${name}/tsig/${key} | base64 -d"
    ]);
  };
in
{
  luffy.hickory-dns = {
    enable = true;
    zones = {
      "y.luffy.cx" = zone "y.luffy.cx" [ "update.y.luffy.cx" ];
      "acme.luffy.cx" = zone "acme.luffy.cx" [ "update.acme.luffy.cx" ];
    };
  };
}
