{nixpkgs-25-11, ...}: {
  nixpkgs.overlays = [
    (final: prev: let
      # Package set from nixpkgs-25-11 for building gpio-handlers.
      pkgs25 = import nixpkgs-25-11 {
        inherit (prev) system;
        config.allowUnfree = true;
      };
    in {
      # Directly build gpio-handlers with the 25.11 toolchain.
      gpioHandlerPackages = pkgs25.callPackage ./pkgs/gpio-handlers.nix {};
    })
  ];
}
