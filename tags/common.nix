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
    channel.enable = false;
    # Garbage collection
    gc = {
      automatic = true;
      dates = "03:15";
      options = "--delete-older-than 8d";
    };
  };
  # No need to change this when upgrading. See https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";

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
      dnsPropagationCheck = false;
      email = lib.concatStringsSep "@" [
        "letsencrypt+${config.networking.hostName}.${config.networking.domain}"
        "vincent.bernat.ch"
      ];
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
      cpuid
      ethtool
      fzf
      htop
      liboping
      mg
      msr-tools
      mtr
      ncdu
      numactl
      sysstat
      tcpdump
      tmux
    ];
  programs.zsh.enable = true;

  # No X11. This could be done with `environment.noXlibs = true;', but
  # that would require recompiling too many stuff.
  programs.ssh.setXAuthLocation = false;
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
  system.rebuild.enableNg = true;
  system.activationScripts = {
    diff = ''
      PATH=$PATH:${config.nix.package}/bin \
        ${pkgs.nvd}/bin/nvd diff /run/current-system "$systemConfig"
    '';
    reboot-required = ''
      rm -f /run/reboot-required /run/reboot-optional
      [ ! -d /run/booted-system ] || {
        ${pkgs.diffutils}/bin/cmp -s /run/booted-system/nixos-version /run/current-system/nixos-version || {
          touch /run/reboot-required
          >&2 echo '*** Reboot required (new NixOS)'
        }
        booted="$(readlink /run/booted-system/{initrd,kernel,kernel-modules})"
        built="$(readlink "$systemConfig"/{initrd,kernel,kernel-modules})"
        [ "$booted" = "$built" ] || {
          touch /run/reboot-optional
          >&2 echo '*** Reboot optional (kernel changed)'
        }
      }
    '';
  };

}
