{
  description = "DartkitOS - NixOS-based Raspberry Pi 4 SD image with wifi-connect captive portal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];

    nixosConfig = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit nixos-hardware;};
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-4
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ./modules/wifi-connect.nix
        ./modules/autodarts.nix
        ./configuration.nix
        ./sd-image.nix
      ];
    };
  in {
    nixosConfigurations.dartkitos = nixosConfig;

    # Build from any system — the derivations are aarch64-linux # regardless
    # x86-linux needs binfmt/qemu
    # aarch64-darwin needs linux builder
    packages = nixpkgs.lib.genAttrs systems (_: {
      default = nixosConfig.config.system.build.toplevel;
      sdImage = nixosConfig.config.system.build.sdImage;
    });
  };
}
