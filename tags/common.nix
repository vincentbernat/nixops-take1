{ inputs, config, pkgs, lib, ... }:
let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOfsoHyVxxBYhzmukmFU0CrPfF4XywU+8rA1NAmZiCji bernat@chocobo"
  ];
in
{
  # Nix
  nix = {
    # Only use Flakes
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ ];
    # Garbage collection
    gc = {
      automatic = true;
      dates = "03:15";
      options = "--delete-older-than 8d";
    };
  };
  # no need to change this when upgrading. See https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "18.09";

  # Firewall
  networking.firewall = {
    enable = true;
    rejectPackets = true;
    allowPing = true;
    allowedTCPPorts = [ 22 ];
  };
  networking.nat.externalInterface = "eth0";

  # Better performance
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.ipv4.tcp_min_snd_mss" = 536;
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults = {
      validMinDays = 174;
      dnsResolver = "1.1.1.1:53";
      email = lib.concatStringsSep "@" [
        "buypass+${config.networking.hostName}.${config.networking.domain}"
        "vincent.bernat.ch"
      ];
      server = "https://api.buypass.com/acme/directory";
    };
  };

  # Services
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      AcceptEnv = "LANG LC_*";
    };
  };
  services.fstrim = {
    enable = true;
  };
  services.logrotate.enable = true;

  # Packages
  environment.systemPackages = with pkgs;
    [
      bat
      fzf
      htop
      liboping
      mg
      mtr
      ncdu
      tmux
    ];
  programs.zsh.enable = true;

  # No X11. This could be done with `environment.noXlibs = true;', but
  # that would require recompiling too many stuff.
  security.pam.services.su.forwardXAuth = lib.mkForce false;
  fonts.fontconfig.enable = false;

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

  documentation.enable = false;
  system.activationScripts.diff = ''
    PATH=$PATH:${config.nix.package}/bin \
      ${pkgs.nvd}/bin/nvd diff /run/current-system "$systemConfig"
  '';

}
