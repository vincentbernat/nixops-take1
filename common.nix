{ inputs }: { config, pkgs, lib, ... }:
let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOfsoHyVxxBYhzmukmFU0CrPfF4XywU+8rA1NAmZiCji bernat@chocobo"
  ];
in
{
  # Nix
  nix = {
    # Only use Flakes
    package = pkgs.nix_2_4;
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
  networking.firewall.enable = true;
  networking.firewall.rejectPackets = true;
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Better performance
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.ipv4.tcp_min_snd_mss" = 536;
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Let's Encrypt
  security.acme = {
    acceptTerms = true;
    email = lib.concatStringsSep "@" [
      "buypass+${config.deployment.targetHost}"
      "vincent.bernat.ch"
    ];
    server = "https://api.buypass.com/acme/directory";
  };

  # Services
  services.openssh = {
    enable = true;
    permitRootLogin = "prohibit-password";
    extraConfig = "AcceptEnv LANG LC_*";
  };
  services.fstrim = {
    enable = true;
  };
  services.logrotate = {
    enable = true;
    paths = {
      btmp = {
        path = "/var/log/btmp";
        frequency = "weekly";
        keep = 3;
      };
      wtmp = {
        path = "/var/log/wtmp";
        frequency = "monthly";
        keep = 12;
      };
    };
  };

  # Packages
  environment.systemPackages = with pkgs;
    [
      bat
      htop
      liboping
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
      extraGroups = [ "wheel" ];
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
