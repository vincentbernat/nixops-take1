{ inputs }:
let
  lib = inputs.nixpkgs.lib;
  shortName = name: builtins.elemAt (lib.splitString "." name) 0;
  domainName = name: lib.concatStringsSep "." (builtins.tail (lib.splitString "." name));
  server = { name, ipv4Address, ipv6Address, modules }: {
    deployment.targetHost = name;
    imports = [
      {
        _module.args = {
          inherit inputs ipv4Address ipv6Address;
        };
      }
      {
        networking = {
          hostName = shortName name;
          domain = domainName name;
        };
      }
      ./tags/common.nix
    ] ++ modules;
  };
  cdktf-servers-json = (lib.importJSON ./cdktf.json).servers.value;
  cdktf-servers = map
    (s:
      let
        tag-imports = builtins.filter (t: builtins.pathExists t) (map (t: ./tags + "/${t}.nix") s.tags);
      in
      {
        name = shortName s.name;
        value = server {
          inherit (s) name ipv4Address ipv6Address;
          modules = [
            (./hardware/. + "/${s.hardware}.nix")
          ] ++ tag-imports;
        };
      })
    cdktf-servers-json;
in
{
  meta = {
    description = "Luffy infrastructure";
    nixpkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
    };
  };
} // builtins.listToAttrs cdktf-servers
