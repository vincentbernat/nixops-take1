{ config, modulesPath, ... }:
let
  host = config.luffy.host;
in
{
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
  boot.loader.grub.device = "/dev/vda";
  boot.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859_1" ]; # /efi with autofs
  boot.kernel.sysctl = {
    "net.ipv6.conf.eth0.accept_ra" = 0;
  };
  networking = {
    usePredictableInterfaceNames = false;
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [{
      address = host.ipv4Address;
      prefixLength = 32;
    }];
    defaultGateway = {
      address = host.gateway4;
      interface = "eth0";
    };
    interfaces.eth0.ipv6.addresses = [{
      address = host.ipv6Address;
      prefixLength = 128;
    }];
    defaultGateway6 = {
      address = host.gateway6;
      interface = "eth0";
    };
  };
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
}
