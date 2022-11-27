This is my tentative to get more familiar with NixOS and NixOps. I am
unsure if it's the right way.

NixOps is very nice on some aspects, notably the ability to lookup
configuration of other nodes but it seems there is not many people
using it and there are some lingering bugs, like the inability to
reboot when a kernel is updated or the poor support for `nixops
show-option`.

I am using this setup in conjuction with CDKTF. See [cdktf-take1
repository](https://github.com/vincentbernat/cdktf-take1). Notably,
`cdktf.json` is the output of

    terraform output --json > cdktf.json

To deploy NixOS on Hetzner, see
https://blog.oro.nu/posts/hetzner-cloud-with-nixos/. On Vultr, this
can be done directly from a custom ISO.

First, enable the appropriate shell:

    nix develop -c $SHELL

To create:

    nixops create ./network.nix -d luffy

To deploy:

    nix flake lock --update-input nixpkgs
    nixops deploy

In case of a security issue, it can take a few days to get the current
release to be updated. Usually, switching to the small version helps
by setting version to `22.05-small` in `flake.nix`.

If a reboot is needed, `--allow-reboot` as no effect. Reboot should be
done manually or with:

    nixops deploy --force-reboot

See https://github.com/NixOS/nixops/issues/367.
