{
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    packages = pkgs.lib.optionalAttrs (system == "aarch64-linux") {
      gpio-handlers = pkgs.callPackage ({
      rustPlatform,
      lib,
      libgpiod,
    }:
      rustPlatform.buildRustPackage {
        pname = "gpio-handlers";
        version = "0.1.0";

        src = ../gpio-handlers;

        cargoLock.lockFile = ../gpio-handlers/Cargo.lock;

        buildInputs = [libgpiod];

        meta = with lib; {
          description = "GPIO handler daemons (button-handler and led-handler) for DartkitOS";
          license = licenses.mit;
          platforms = ["aarch64-linux"];
        };
      }) {};
    };
  };
}
