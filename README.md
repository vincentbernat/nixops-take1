This is my tentative to get more familiar with NixOS and Colmena. This looks
better than a couple years back. Previously, I was using NixOps (see commit
7e583aca7906).

# Installing NixOS

NixOS can be installed from some rescue system.

```
sfdisk /dev/vda <<EOF
label: dos
size=1GiB, type=82
type=83, bootable
EOF
mkswap -L swap /dev/vda1
mkfs.ext4 -L nixos /dev/vda2

swapon /dev/vda1
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/nix /nix
mount --bind /mnt/nix /nix

curl -sSfL https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm
```

Then build the configuration and deploy it:

```
colmena build --on web07
nix copy --no-check-sigs \
  --to 'ssh-ng://root@web07.luffy.cx?remote-program=/nix/var/nix/profiles/default/bin/nix-daemon' \
  /nix/store/rbgyan1paa9j9jgq3n9az62qhbz0ba65-nixos-system-web07-26.05pre-git
```

Then, back to the system:

```
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix shell nixpkgs#nixos-install-tools
nixos-install --root /mnt \
  --system /nix/store/rbgyan1paa9j9jgq3n9az62qhbz0ba65-nixos-system-web07-26.05pre-git \
  --no-root-passwd
reboot
```

# Deploy

I am using this setup in conjuction with CDKTF. See [cdktf-take1
repository](https://github.com/vincentbernat/cdktf-take1). Notably,
`cdktf.json` is the output of

    terraform output --json > cdktf.json

First, enable the appropriate shell:

    nix develop -c $SHELL

To deploy:

    nix flake update nixpkgs
    colmena apply

Add `--verbose` to not cut the logs to 20 lines.

To deploy hosts one by one (all of them by default), run the following command.
It builds and copies everything first. Then, for each host, it reboots if the
kernel, the initrd, the modules or the NixOS version changed, otherwise it
switches. Tests are run after each host and the deployment stops on the first
failure.

    nix run .#deploy [HOST...]

TLS certificates are requested from the workstation and stored in pass. To
request missing certificates, renew the others when Let's Encrypt suggests it
(ARI) or when they expire in less than 30 days, and upload them:

    nix run .#certificates
    colmena upload-keys

To check if the hosts change between two revisions (`OLD` defaults to `HEAD~1`,
`NEW` to `HEAD`), run the following command. No output means no change:

    nix run .#compare [OLD] [NEW]

In case of a security issue, it can take a few days to get the current
release to be updated. Usually, switching to the small version helps
by setting version to `23.05-small` in `flake.nix`.
