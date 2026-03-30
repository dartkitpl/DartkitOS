{self, ...}: {
  perSystem = {self', ...}: {
    # Regardless of host system, the output will be aarch64-linux system/image
    # That's because nixosConfigurations have the system baked in
    # No need to specify system explicitly (like in `nix build --system aarch64-linux`)
    packages = {
      default = self'.packages.dartkitos;

      dartkitos = self.nixosConfigurations.dartkitos.config.system.build.toplevel;
      sdImage = self.nixosConfigurations.dartkitos.config.system.build.sdImage;

      dev = self.nixosConfigurations.dev.config.system.build.toplevel;
      sdImageDev = self.nixosConfigurations.dev.config.system.build.sdImage;
    };
  };
}
