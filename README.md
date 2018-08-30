This is my tentative to get more familiar with NixOS and NixOps. I am
unsure if it's the right way.

NixOps is very nice on some aspects, notably the ability to lookup
configuration of other nodes but it seems there is not many people
using it and there are some lingering bugs, like the inability to
reboot when a kernel is updated or the poor support for `nixops
show-option`. An alternate approach would be to use Terraform with
NixOS.

# Commands

To spawn a new NixOS instance (in DE-FRA-1, tiny instance):

    cs deployVirtualMachine \
      templateid=39c4d964-be74-4d35-bd32-e0ed832660cd \
      zoneid=35eb7739-d19e-45f7-a581-4687c54d6d02 \
      serviceofferingId=b6cd1ff5-3a2f-4e9d-a4d1-8988c1191fe8 \
      rootdisksize=10 \
      ip6=true \
      keypair=VM \
      securitygroupnames=base,web \
      affinitygroupnames=web \
      displayname=web01.luffy.cx \
      name=web01.luffy.cx

Register the name in the DNS. Copy SSH key for the root account:

    ssh-copy-id -f -i ~/.ssh/luffy/ed25519.pub exo.89.145.165.224.nip.io

To create:

    ./nixops create ./network.nix -d luffy

To deploy:

    ./nixops deploy -d luffy

If a reboot is needed, `--allow-reboot` as no effect. Reboot should be
done manually or with:

    ./nixops deploy -d luffy --force-reboot

See https://github.com/NixOS/nixops/issues/367.
