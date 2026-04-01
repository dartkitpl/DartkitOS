
{
  self,
  ...
}: {
  flake.nixosModules.rpi4 = {
    lib,
    nixos-hardware,
    pkgs,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.sdImage
      nixos-hardware.nixosModules.raspberry-pi-4
    ];

    boot = {
      loader = {
        grub.enable = false;
        generic-extlinux-compatible.enable = true;
      };

      kernelParams = [
        "console=ttyS1,115200n8"
        "console=tty0"
        "quiet"
        "loglevel=3"
        "consoleblank=0"
        "printk.devkmsg=on"
      ];

      kernel.sysctl = {
        "kernel.printk" = "3 3 3 3";
      };

      kernelModules = ["bcm2835_wdt"];

      # The generic aarch64 SD image includes modules for many ARM SoCs.
      initrd.availableKernelModules = lib.mkForce [
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "mmc_block"
        "ext4"
        "vfat"
        "nls_cp437"
        "nls_iso8859_1"
      ];
    };

    hardware = {
      raspberry-pi."4" = {
        apply-overlays-dtmerge.enable = true;
        fkms-3d.enable = false;
      };

      enableRedistributableFirmware = true;
      firmware = [pkgs.raspberrypiWirelessFirmware];
    };

    environment.systemPackages = with pkgs; [
      libraspberrypi
      raspberrypi-eeprom
    ];

    sdImage = {
      imageName = "dartkitos-rpi4-${config.system.nixos.label}.img";
      firmwareSize = 256;
    };
  };
}
