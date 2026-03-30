{
  flake.nixosModules.sdImage = {
    config,
    lib,
    nixpkgs,
    ...
  }: {
    imports = [
      "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ];

    # Compress the final image with zstd for smaller download
    sdImage.compressImage = true;

    # Image name for easy identification
    sdImage.imageName = "dartkitos-rpi4-${config.system.nixos.label}.img";

    # Firmware partition configuration
    # The boot partition needs enough space for kernel + firmware
    sdImage.firmwareSize = 256; # MB

    nixpkgs.config.allowUnfree = true;

    # ============================================================
    # Fix: Override initrd to exclude modules not in Pi kernel
    # ============================================================
    # The generic aarch64 SD image includes modules for many ARM SoCs.
    # We restrict to only those needed for Raspberry Pi 4.
    boot.initrd.availableKernelModules = lib.mkForce [
      # USB
      "xhci_pci"
      "usbhid"
      "usb_storage"
      # SD/MMC
      "mmc_block"
      # Filesystems
      "ext4"
      "vfat"
      "nls_cp437"
      "nls_iso8859_1"
    ];
  };
}
