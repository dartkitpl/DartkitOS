{
  rustPlatform,
  lib,
  libgpiod,
}:
rustPlatform.buildRustPackage {
  pname = "button-handler";
  version = "0.1.0";

  src = ../button-handler;

  cargoLock.lockFile = ../button-handler/Cargo.lock;

  buildInputs = [libgpiod];

  meta = with lib; {
    description = "Button handler daemon for DartkitOS";
    license = licenses.mit;
    platforms = ["aarch64-linux"];
  };
}

