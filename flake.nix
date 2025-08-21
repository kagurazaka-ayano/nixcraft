{
  description = "A declarative minecraft server creation system";

  inputs = {nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";};

  outputs = {
    self,
    nixpkgs,
  }: {
    nixosModules.mcserver = import ./mcserver.nix;

    nixosModules.default = self.nixosModules.mcserver;
  };
}
