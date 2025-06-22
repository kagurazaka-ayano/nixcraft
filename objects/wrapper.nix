{ lib, pkgs, props, ... }:
let files = props.plugins ++ props.confs;

in {
  imports = [
    (import ../utils/filelist.nix {
      inherit pkgs files lib;
      root = props.root;
    })
  ];
}
