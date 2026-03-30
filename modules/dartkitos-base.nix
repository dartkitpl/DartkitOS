{self, ...}: {
  flake.nixosModules.dartkitosBase = {
    imports = [
      self.nixosModules.dartkitosSystem
      self.nixosModules.otaUpdate
      self.nixosModules.gpioHandlers

      self.nixosModules.autodarts
      self.nixosModules.wifiSetup

      self.nixosModules.sdImage
    ];
  };
}
