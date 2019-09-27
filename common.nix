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

  # Packages
  environment.systemPackages =
    [ pkgs.htop pkgs.mg pkgs.mtr pkgs.ncdu pkgs.tmux pkgs.zsh ];
  programs.zsh.enable = true;

  # Users
  users = {
    mutableUsers = false;
    users.root.openssh.authorizedKeys.keys = sshKeys;
    users.bernat = {
      isNormalUser = true;
      home = "/home/bernat";
      description = "Vincent Bernat";
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = sshKeys;
    };
  };
  security.sudo.wheelNeedsPassword = false;

  # Install my own zshrc. For some reason, the newuser function is
  # running quite early and zshenv also aborts early.
  environment.etc."zprofile.local" = {
    text = ''
      [ -f ''${HOME}/.zshrc ] || \
        ${pkgs.curl}/bin/curl -s https://vincentbernat-zshrc.s3.amazonaws.com/zsh-install.sh | sh
    '';
    mode = "0555";
  };
}
