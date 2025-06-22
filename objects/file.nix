{ lib, pkgs, mod, ... }:
let
  local = builtins.hasAttr "path" mod;
  suffix = if builtins.hasAttr "suffix" mod then
    (if (lib.strings.hasPrefix "." mod.suffix) then
      mod.suffix
    else
      "." + mod.suffix)
  else
    (if local then
      ("." + (lib.lists.last (builtins.split ".*[.]" "${mod.path}")))
    else
      ("." + (lib.lists.last (builtins.split ".*[.]" mod.url))));

  name = if !(lib.strings.hasSuffix "${suffix}" mod.name) then
    "${mod.name}${suffix}"
  else
    mod.name;
  location = if local then
    "${mod.path}"
  else
    ''$(find $src -name "*${suffix}" | head -n 1)'';
  unpackPhase = "mkdir -p $out && cp ${location} $out";
  installPhase = "cp ${location} $out/${name}";
in {
  dir = mod.dir;
  inherit local name;
  value = pkgs.stdenv.mkDerivation {
    pname = mod.name;
    version = "dummy";
    src = if local then
      mod.path
    else
      pkgs.fetchurl {
        url = mod.url;
        hash =
          mod.hash or "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };
    inherit unpackPhase installPhase;

  };
}

