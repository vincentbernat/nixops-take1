{ inputs }:
let
  lib = inputs.nixpkgs.lib;
  shortName = name: builtins.elemAt (lib.splitString "." name) 0;
  domainName = name: lib.concatStringsSep "." (builtins.tail (lib.splitString "." name));
  server = hardware: name: imports: extras: extras // {
    networking = (if extras ? "networking" then extras.networking else { }) // {
      hostName = shortName name;
      domain = domainName name;
    };
    deployment.targetHost = name;
    imports = [ (./hardware/. + "/${hardware}.nix") ] ++ imports;
  };
  cdktf-servers-json = (lib.importJSON ./cdktf.json).servers.value;
  cdktf-servers = map
    (s:
      let
        tags-import = builtins.filter (t: builtins.pathExists t) (map (t: ./. + "/${t}.nix") s.tags);
        extra-attrs =
          if s.hardware == "hetzner"
          then {
            networking.usePredictableInterfaceNames = false;
            networking.interfaces.eth0.ipv6.addresses = [{
              address = s.ipv6Address;
              prefixLength = 64;
            }];
            networking.defaultGateway6 = {
              address = "fe80::1";
              interface = "eth0";
            };
          }
          else { };
      in
      {
        name = shortName s.name;
        value = server s.hardware s.name tags-import extra-attrs;
      })
    cdktf-servers-json;
in
{
  nixpkgs = inputs.nixpkgs;
  network.description = "Luffy infrastructure";
  network.enableRollback = true;
  network.storage.legacy = { };
  defaults = import ./common.nix { inherit inputs; };
} // builtins.listToAttrs cdktf-servers
