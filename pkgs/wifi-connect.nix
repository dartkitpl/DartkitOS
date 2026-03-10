# ============================================================
# wifi-connect package
# ============================================================
# Balena's wifi-connect is the de-facto standard for captive portal
# Wi-Fi configuration on IoT devices. We fetch the pre-built aarch64
# binary from their releases.
#
# The UI is our custom Flutter captive portal (captive_portal/), built
# from source using buildFlutterApplication and bundled as a web app.
#
# NOTE: If the binary hash is incorrect, run:
#   nix-prefetch-url https://github.com/balena-os/wifi-connect/releases/download/v4.11.84/wifi-connect-aarch64-unknown-linux-gnu.tar.gz
# Then convert to SRI format:
#   nix hash to-sri --type sha256 <hash>
#
# NOTE: After changing Dart/Flutter dependencies, rebuild once and
# replace vendorHash with the hash from the error message.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
  dbus,
  gcc,
  flutter,
}:
let
  # ── Captive portal UI (Flutter web) ───────────────────────────────
  captivePortalUi = flutter.buildFlutterApplication {
    pname = "captive-portal-ui";
    version = "1.0.0";
    src = ../captive_portal;

    # Points to the lockfile so Nix can fetch Dart deps reproducibly.
    autoPubspecLock = ../captive_portal/pubspec.lock;

    # Use the built-in web target instead of Linux desktop.
    # This provides correct build/install phases:
    #   build:   flutter build web -v
    #   install: cp -r build/web "$out"
    # Dependencies are resolved through dartConfigHook's package_config.json,
    # NOT through the pub cache, so "flutter pub get" is not needed.
    targetFlutterPlatform = "web";
  };
in
stdenv.mkDerivation rec {
  pname = "wifi-connect";
  version = "4.11.84";

  src = fetchurl {
    url = "https://github.com/balena-os/wifi-connect/releases/download/v${version}/wifi-connect-aarch64-unknown-linux-gnu.tar.gz";
    sha256 = "sha256-QT1w5tHBNmy+KzJVXoR28+koeBeO0bnIIgWYXwVfGTY=";
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
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/wifi-connect
    cp wifi-connect $out/bin/
    cp -r ${captivePortalUi} $out/share/wifi-connect/ui
  '';

  meta = with lib; {
    description = "Easy WiFi setup for IoT devices";
    homepage = "https://github.com/balena-os/wifi-connect";
    license = licenses.asl20;
    platforms = ["aarch64-linux"];
  };
}
