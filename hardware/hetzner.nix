{ ... }:
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
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  ];
}
