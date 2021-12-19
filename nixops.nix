let
  lib = import <nixpkgs/lib>;
  shortName = name: builtins.elemAt (lib.splitString "." name) 0;
  domainName = name: lib.concatStringsSep "." (builtins.tail (lib.splitString "." name));
  server = hardware: name: imports: extras: extras // {
    networking = (if extras ? "networking" then extras.networking else {}) // {
      hostName = shortName name;
      domain = domainName name;
    };
    deployment.targetHost = name;
    imports = [ (./hardware/. + "/${hardware}.nix") ] ++ imports;
  };
  extra-imports = {
    "web03.luffy.cx" = [ ./isso.nix ];
  };
  web-servers-json = (lib.importJSON ./pulumi.json).www-servers;
  web-servers = map (s: let
    web-imports = if extra-imports ? ${s.name}
              then extra-imports.${s.name}
              else [];
    extra-attrs = if s.kind == "hetzner"
            then {
              networking.usePredictableInterfaceNames = false;
              networking.interfaces.eth0.ipv6.addresses = [{
                address = s.ipv6_address;
                prefixLength = 64;
              }];
              networking.defaultGateway6 = {
                address = "fe80::1";
                interface = "eth0";
              };
            }
            else {};
  in {
    name = shortName s.name;
    value = server s.kind s.name ([ ./web.nix ] ++ web-imports) extra-attrs;
  }) web-servers-json;
in {
  network.description = "Luffy infrastructure";
  network.enableRollback = true;
  network.storage.legacy = {};
  defaults = import ./common.nix;
} // builtins.listToAttrs web-servers
