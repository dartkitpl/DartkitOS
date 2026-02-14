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

    # Derive version from the flake's source info.
    # - self.rev: full commit SHA from a clean git checkout or github: flake ref
    # - self.dirtyRev: commit SHA + "-dirty" when there are uncommitted changes
    # - "non-git": fallback when built from tarball/zip without .git directory
    #
    # The OTA update script compares this against the commit SHA
    # associated with the latest GitHub Release tag.
    version =
      if self ? rev
      then self.rev
      else if self ? dirtyRev
      then self.dirtyRev
      else "non-git";

    nixosConfig = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        inherit nixos-hardware;
        dartkitosVersion = version;
      };
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-4
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ./modules/wifi-connect.nix
        ./modules/autodarts.nix
        ./modules/ota-update.nix
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
