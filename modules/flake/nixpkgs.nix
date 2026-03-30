{inputs, ...}: {
  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;

      config.allowUnfree = true;

      overlays = [
        (final: prev: {
          # Package set from nixpkgs-25-11
          nixpkgs25 = import inputs.nixpkgs-25-11 {
            inherit (prev) system;
            config.allowUnfree = true;
          };
        })
      ];
    };
  };
}
