{
  flake.nixosModules.rpi4 = {
    lib,
    nixos-raspberrypi,
    pkgs,
    config,
    ...
  }: {
    imports = with nixos-raspberrypi.nixosModules; [
      sd-image
      raspberry-pi-4.base
    ];

    boot = {
      loader = {
        raspberry-pi.bootloader = "uboot";
      };

      kernelModules = ["bcm2835_wdt"];
    };

    hardware.enableAllHardware = lib.mkForce false;
    boot.supportedFilesystems.zfs = lib.mkForce false;
    system.nixos.tags = lib.mkForce [];

    environment.systemPackages = with pkgs; [
      libraspberrypi
      raspberrypi-eeprom
    ];

    image.fileName = "dartkitos-rpi4-${config.system.nixos.label}.img";
    sdImage.compressImage = true;
  };
}
