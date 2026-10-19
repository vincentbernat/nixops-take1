{ lib, buildGoModule, ... }:

buildGoModule {
  pname = "http-over-ssh-auth";
  version = "0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (file: lib.hasSuffix ".go" file.name || file.name == "go.mod") ./.;
  };
  vendorHash = null;
  env.CGO_ENABLED = 0;
  meta.mainProgram = "http-over-ssh-auth";
}
