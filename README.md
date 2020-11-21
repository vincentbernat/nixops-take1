This is my tentative to get more familiar with NixOS and NixOps. I am
unsure if it's the right way.

NixOps is very nice on some aspects, notably the ability to lookup
configuration of other nodes but it seems there is not many people
using it and there are some lingering bugs, like the inability to
reboot when a kernel is updated or the poor support for `nixops
show-option`. An alternate approach would be to use Terraform with
NixOS.

To deploy NixOS on Hetzner, see https://blog.oro.nu/posts/hetzner-cloud-with-nixos/

To create:

    ./nixops create ./network.nix -d luffy

To deploy:

    ./nixops deploy

If a reboot is needed, `--allow-reboot` as no effect. Reboot should be
done manually or with:

    ./nixops deploy --force-reboot

See https://github.com/NixOS/nixops/issues/367.
