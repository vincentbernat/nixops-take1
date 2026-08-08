# Packages we build ourselves. They are available as `pkgs.luffy.*'.
final: prev: {
  luffy = {
    isso = final.callPackage ./isso.nix { };
    nginx = final.callPackage ./nginx.nix { };
  };
}
