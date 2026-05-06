{
  flake.nixosModules.rpi5 = {
    lib,
    nixos-raspberrypi,
    pkgs,
    config,
    ...
  }: {
    imports = with nixos-raspberrypi.nixosModules; [
      sd-image
      raspberry-pi-5.base
      raspberry-pi-5.page-size-16k
    ];

    boot = {
      loader = {
        raspberry-pi.bootloader = "kernel";
      };

      kernelModules = ["bcm2835_wdt"];

      extraModprobeConfig = ''
        options brcmfmac roamoff=1
      '';
    };

    hardware.enableAllHardware = lib.mkForce false;
    boot.supportedFilesystems.zfs = lib.mkForce false;
    system.nixos.tags = lib.mkForce [];

    environment.systemPackages = with pkgs; [
      libraspberrypi
      raspberrypi-eeprom
    ];

    image.fileName = "dartkitos-rpi5-${config.system.nixos.label}.img";
    sdImage.compressImage = true;
  };
}
