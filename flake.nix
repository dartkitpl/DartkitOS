{
  description = "DartkitOS - NixOS-based Raspberry Pi 4 SD image with wifi-connect captive portal";

  inputs = {
    # Use a stable NixOS release for production reliability
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Provides additional Raspberry Pi hardware support
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    ...
  }: let
    # ============================================================
    # Cross-compilation setup
    # ============================================================
    # Build system: x86_64-linux (your build machine)
    # Target system: aarch64-linux (Raspberry Pi 4)
    targetSystem = "aarch64-linux";
  in {
    # ============================================================
    # NixOS Configuration for Raspberry Pi 4
    # ============================================================
    nixosConfigurations.dartkitos = nixpkgs.lib.nixosSystem {
      # Targetting Raspberry Pi 4 architecture
      # Must have binfmt/qemu setup for emulation if building on x86_64
      system = targetSystem;

      # Pass special args to modules
      specialArgs = {
        inherit nixos-hardware;
      };

      modules = [
        # Raspberry Pi 4 hardware support from nixos-hardware
        nixos-hardware.nixosModules.raspberry-pi-4

        # Official NixOS SD image module for aarch64
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"

        # Our custom modules
        ./modules/wifi-connect.nix
        ./modules/autodarts.nix
        ./configuration.nix

        # ============================================================
        # SD Image Configuration
        # ============================================================
        ({config, lib, ...}: {
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
        })
      ];
    };

    # ============================================================
    # Build outputs
    # ============================================================
    # Build the SD image with: nix build .#sdImage
    packages.x86_64-linux = {
      sdImage = self.nixosConfigurations.dartkitos.config.system.build.sdImage;
      default = self.packages.x86_64-linux.sdImage;
    };

    # Also expose for aarch64-linux builds (if building natively on Pi)
    packages.aarch64-linux = {
      sdImage = self.nixosConfigurations.dartkitos.config.system.build.sdImage;
      default = self.packages.aarch64-linux.sdImage;
    };
  };
}
