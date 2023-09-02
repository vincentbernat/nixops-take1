This is my tentative to get more familiar with NixOS and Colmena. I am unsure if
it's the right way. Previously, I was using NixOps (see commit 7e583aca7906).

I am using this setup in conjuction with CDKTF. See [cdktf-take1
repository](https://github.com/vincentbernat/cdktf-take1). Notably,
`cdktf.json` is the output of

    terraform output --json > cdktf.json

To deploy NixOS on Hetzner, see
https://blog.oro.nu/posts/hetzner-cloud-with-nixos/. On Vultr, this
can be done directly from a custom ISO.

First, enable the appropriate shell:

    nix develop -c $SHELL

To deploy:

    nix flake lock --update-input nixpkgs
    colmena apply

To avoid parallelism and reboot after deploying:

    colmena apply --parallel 1 --no-keys --reboot
    colmena apply keys

In case of a security issue, it can take a few days to get the current
release to be updated. Usually, switching to the small version helps
by setting version to `23.05-small` in `flake.nix`.
