{
  flake.nixosModules.sdImage = {
    nixpkgs,
    ...
  }: {
    imports = [
      "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ];

    # Compress the final image with zstd for smaller download
    sdImage.compressImage = true;

    nixpkgs.config.allowUnfree = true;
  };
}
