{
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    packages = pkgs.lib.optionalAttrs (system == "aarch64-linux") {
      wifi-connect = pkgs.callPackage ({
      lib,
      stdenv,
      fetchurl,
      autoPatchelfHook,
      glibc,
      dbus,
      gcc,
    }:
      stdenv.mkDerivation rec {
        pname = "wifi-connect";
        version = "4.11.84";

        src = fetchurl {
          url = "https://github.com/balena-os/wifi-connect/releases/download/v${version}/wifi-connect-aarch64-unknown-linux-gnu.tar.gz";
          sha256 = "sha256-QT1w5tHBNmy+KzJVXoR28+koeBeO0bnIIgWYXwVfGTY=";
        };

        # Fetch the UI separately (it's now a separate download)
        ui = fetchurl {
          url = "https://github.com/balena-os/wifi-connect/releases/download/v${version}/wifi-connect-ui.tar.gz";
          sha256 = "sha256-5Xo87FWXKVFt7PiSvrHn8ZGyPnGy4TvNQ9NrmAA0/74=";
        };

        nativeBuildInputs = [autoPatchelfHook];
        buildInputs = [
          glibc
          dbus
          gcc.cc.lib # Provides libgcc_s.so.1
        ];

        sourceRoot = ".";

        unpackPhase = ''
          tar -xzf $src
          mkdir -p ui
          tar -xzf $ui -C ui
        '';

        installPhase = ''
          mkdir -p $out/bin $out/share/wifi-connect
          cp wifi-connect $out/bin/
          cp -r ui $out/share/wifi-connect/
        '';

        meta = with lib; {
          description = "Easy WiFi setup for IoT devices";
          homepage = "https://github.com/balena-os/wifi-connect";
          license = licenses.asl20;
          platforms = ["aarch64-linux"];
        };
      }) {};
    };
  };
}
