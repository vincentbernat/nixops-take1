{ config, pkgs, ... }:
let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETuPJlu22nwrDxwiqAvrFbPvSIRq03g2PDGrLwMy299 bernat@zoro"
  ];
in {
  # Nix
  nix.gc.automatic = true;
  nix.gc.dates = "03:15";
  nix.gc.options = "--delete-older-than 30d";
  # no need to change this when upgrading. See https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "18.09";

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.rejectPackets = true;
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  boot.kernel.sysctl."net.ipv4.tcp_min_snd_mss" = 536;

  # Services
  services.openssh = {
    enable = true;
    permitRootLogin = "prohibit-password";
    extraConfig = "AcceptEnv LANG LC_*";
  };

  services.fstrim = {
    enable = true;
  };

  # Packages
  environment.systemPackages = with pkgs;
    [
      bat
      htop
      mg
      mtr
      ncdu
      tmux
    ];
  programs.zsh.enable = true;

  # Users
  users = {
    mutableUsers = false;
    users.root.openssh.authorizedKeys.keys = sshKeys;
    users.bernat = {
      isNormalUser = true;
      home = "/home/bernat";
      description = "Vincent Bernat";
      extraGroups = [ "wheel" "nginx" ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = sshKeys;
    };
  };
  security.sudo.wheelNeedsPassword = false;

  system.activationScripts.diff = ''
    ${pkgs.nixUnstable}/bin/nix store \
        --experimental-features 'nix-command' \
        diff-closures /run/current-system "$systemConfig"
  '';

}
