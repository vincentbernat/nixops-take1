{ modulesPath, lib, ipv4Address, ipv6Address, tags, ... }:
let
  taggedValue = prefix:
    lib.strings.removePrefix "${prefix}:" (builtins.head (builtins.filter (t: lib.strings.hasPrefix "${prefix}:" t) tags));
in
{
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
  boot = {
    loader.grub.device = "/dev/vda";
    loader.timeout = 0;
    initrd = {
      availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
      kernelModules = [ "nvme" ];
    };
  };
  services.resolved.enable = true;
  networking = {
    usePredictableInterfaceNames = false;
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [{
      address = ipv4Address;
      prefixLength = 32;
    }];
    defaultGateway = {
      address = taggedValue "gateway4";
      interface = "eth0";
    };
    interfaces.eth0.ipv6.addresses = [{
      address = ipv6Address;
      prefixLength = 128;
    }];
    defaultGateway6 = {
      address = taggedValue "gateway6";
      interface = "eth0";
    };
  };
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
}
