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

    mkNixosConfig = configuration:
      nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          inherit nixos-hardware nixpkgs;
          dartkitosVersion = version;
        };
        modules = [
          ./modules
          configuration
        ];
      };
  in rec {
    nixosConfigurations = {
      dartkitos = mkNixosConfig ./configurations/prod.nix;
      dev = mkNixosConfig ./configurations/dev.nix;
    };

    # Build from any system — the derivations are aarch64-linux # regardless
    # x86-linux needs binfmt/qemu
    # aarch64-darwin needs linux builder
    packages = nixpkgs.lib.genAttrs systems (_: {
      default = nixosConfigurations.dartkitos.config.system.build.toplevel;
      sdImage = nixosConfigurations.dartkitos.config.system.build.sdImage;
    });
  };
}
