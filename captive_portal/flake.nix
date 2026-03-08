{
  description = "Flutter development environment with Android support";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };
    };
    # https://nixos.org/manual/nixpkgs/stable/#deploying-an-android-sdk-installation-with-plugins
    androidPkgs = pkgs.androidenv.composeAndroidPackages {
      toolsVersion = "26.1.1";
      platformToolsVersion = "36.0.0";
      buildToolsVersions = ["34.0.0" "35.0.0"];
      platformVersions = ["34" "35" "36"];

      includeCmake = true;
      cmakeVersions = ["3.22.1"];

      includeEmulator = true;

      includeNDK = true;
      ndkVersions = ["28.2.13676358"];

      abiVersions = ["armeabi-v7a" "arm64-v8a" "x86_64"];
      systemImageTypes = ["google_apis_playstore"];
    };
  in {
    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = with pkgs; [
        flutter
        androidPkgs.androidsdk
        androidPkgs.platform-tools
        androidPkgs.build-tools
        androidPkgs.emulator
        android-tools
        cmake
        mesa-demos
        gtk3
        glib.dev
        pkg-config
        sysprof
        jdk17
        chromium

        git
        curl
        unzip
        which
        libGL
        glib
        gcc
        pkg-config
        openssl
      ];
      JAVA_HOME = pkgs.jdk17.home;
      ANDROID_HOME = "${androidPkgs.androidsdk}/libexec/android-sdk";
      ANDROID_SDK_ROOT = "${androidPkgs.androidsdk}/libexec/android-sdk";
      shellHook = ''
        export PATH=$PATH:${androidPkgs.androidsdk}/libexec/android-sdk/platform-tools
        export PATH=$PATH:${androidPkgs.androidsdk}/libexec/android-sdk/emulator
        export PATH=$PATH:${androidPkgs.androidsdk}/libexec/android-sdk/cmdline-tools/latest/bin

        echo "Android SDK and Flutter are ready!"
      '';
    };
  };
}
