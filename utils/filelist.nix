{ lib, pkgs, files ? [ ], root, ... }:
let
  all = (map (mod: (pkgs.callPackage ../objects/file.nix { inherit mod lib; }))
    files);
  path_attrs = builtins.listToAttrs (map (elem: {
    name = "${root}/${elem.dir}/${elem.name}";
    value = {
      source = "${elem.value}/${elem.name}";
      mode = "0655";
    };
  }) all);
in {
  environment.systemPackages = (map (mod: mod.value) all);
  environment.etc = path_attrs;
}
