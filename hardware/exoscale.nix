{ ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
  };
  boot = {
    growPartition = true;
    kernelParams = [ "console=tty0" ];
    loader.grub.device = "/dev/vda";
    loader.timeout = 0;
  };
  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  ];

  # No cloud-init is needed!
}
