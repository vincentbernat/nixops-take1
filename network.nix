{ inputs }:
let
  lib = inputs.nixpkgs.lib;
  shortName = name: builtins.elemAt (lib.splitString "." name) 0;
  domainName = name: lib.concatStringsSep "." (builtins.tail (lib.splitString "." name));
  taggedValue = tags: prefix:
    let
      values = map (lib.removePrefix "${prefix}:") (builtins.filter (lib.hasPrefix "${prefix}:") tags);
    in
    if values == [ ] then null else builtins.head values;
  server = { name, ipv4Address, ipv6Address, tags, modules }: {
    deployment.targetHost = name;
    imports = [
      {
        _module.args = {
          inherit inputs;
        };
        luffy.host = {
          inherit ipv4Address ipv6Address;
          gateway4 = taggedValue tags "gateway4";
          gateway6 = taggedValue tags "gateway6";
          tags = builtins.filter (t: !lib.hasPrefix "gateway4:" t && !lib.hasPrefix "gateway6:" t) tags;
        };
      }
      {
        networking = {
          hostName = shortName name;
          domain = domainName name;
        };
      }
      ./modules
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
          inherit (s) name ipv4Address ipv6Address tags;
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
      overlays = [ inputs.self.overlays.default ];
    };
  };
} // builtins.listToAttrs cdktf-servers
