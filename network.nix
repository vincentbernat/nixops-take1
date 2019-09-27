let
  lib = import <nixpkgs/lib>;
  server = hardware: name: imports: {
    deployment.targetHost = name;
    networking.hostName = name;
    imports = [ (./hardware/. + "/${hardware}.nix") ] ++ imports;
  };
  web = hardware: idx:
    server hardware "web${lib.fixedWidthNumber 2 idx}.luffy.cx" [ ./web.nix ];
in {
  network.description = "Luffy infrastructure";
  defaults = import ./common.nix;
  web03 = web "hetzner" 3 // {
    # Static IPv6 configuration
    networking.interfaces.ens3.ipv6.addresses = [{
      address = "2a01:4f9:c010:1a9c::1";
      prefixLength = 64;
    }];
    networking.defaultGateway6 = {
      address = "fe80::1";
      interface = "ens3";
    };
  };
  web04 = web "hetzner" 4 // {
    # Static IPv6 configuration
    networking.interfaces.ens3.ipv6.addresses = [{
      address = "2a01:4f8:1c0c:5eb5::1";
      prefixLength = 64;
    }];
    networking.defaultGateway6 = {
      address = "fe80::1";
      interface = "ens3";
    };
  };
}
