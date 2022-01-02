{ modulesPath, ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  swapDevices = [ {device = "/dev/disk/by-label/swap";} ];
  boot = {
    loader.grub.device = "/dev/vda";
    loader.timeout = 0;
  };
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
}
