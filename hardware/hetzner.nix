{ modulesPath, ... }:
{
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
    autoResize = true;
  };
  boot = {
    growPartition = true;
    loader.grub.device = "/dev/sda";
    loader.timeout = 0;
  };
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
}
