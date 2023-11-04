{ modulesPath, ipv4Address, ... }:
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
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
}
