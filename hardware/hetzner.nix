{ modulesPath, ipv6Address, ... }:
{
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
    autoResize = true;
  };
  boot = {
    growPartition = true;
    loader.grub.device = "/dev/sda";
  };
  networking = {
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv6.addresses = [{
      address = ipv6Address;
      prefixLength = 64;
    }];
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
  };

  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
}
