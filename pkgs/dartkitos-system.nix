{self, ...}: {
  perSystem = let
    # Generate packages from nixosConfigurations
    packagesFromConfigs =
      builtins.listToAttrs
      (builtins.concatMap (
          configName: let
            nixosConfig = self.nixosConfigurations.${configName};
          in [
            {
              name = "${configName}";
              value = nixosConfig.config.system.build.toplevel;
            }
            {
              name = "sd-${configName}";
              value = nixosConfig.config.system.build.sdImage;
            }
          ]
        )
        (builtins.attrNames self.nixosConfigurations));
  in {
    packages = packagesFromConfigs;
  };
}
