This is my tentative to get more familiar with NixOS and NixOps. I am
unsure if it's the right way.

NixOps is very nice on some aspects, notably the ability to lookup
configuration of other nodes but it seems there is not many people
using it and there are some lingering bugs, like the inability to
reboot when a kernel is updated or the poor support for `nixops
show-option`.

I am using this setup in conjuction with Pulumi. See [pulumi-take1
repository](https://github.com/vincentbernat/pulumi-take1). Notably,
`pulumi.json` is the output of

    pulumi stack output --json > pulumi.json

To deploy NixOS on Hetzner, see
https://blog.oro.nu/posts/hetzner-cloud-with-nixos/. On Vultr, this
can be done directly from a custom ISO.

First, enable the appropriate shell:

    nix-shell

To create:

    nixops create ./network.nix -d luffy

To deploy:

    nixops deploy

In case of a security issue, it can take a few days to get the current
release to be updated. Usually, switching to the small version helps
by setting version to `21.11-small` in `shell.nix`.

    nixops deploy

If a reboot is needed, `--allow-reboot` as no effect. Reboot should be
done manually or with:

    nixops deploy --force-reboot

See https://github.com/NixOS/nixops/issues/367.
