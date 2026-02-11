# ============================================================
# autodarts package
# ============================================================
# Fetch the autodarts binary from the official release server.
# The package downloads and extracts the tarball for the target platform.
#
# NOTE: To update the version, change the version and sha256 below.
# To get the hash, run:
#   nix-prefetch-url https://get.autodarts.io/detection/latest/linux/arm64/autodarts<version>.linux-arm64.tar.gz
# Then convert to SRI format:
#   nix hash to-sri --type sha256 <hash>
{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
  channel ? "latest",
}: let
  # Architecture mapping for autodarts downloads
  archMap = {
    "x86_64-linux" = "amd64";
    "aarch64-linux" = "arm64";
    "armv7l-linux" = "armv7l";
  };

  arch = archMap.${stdenv.hostPlatform.system} or (throw "Unsupported architecture: ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation rec {
    pname = "autodarts";
    version = "1.0.4";

    src = fetchurl {
      url = "https://get.autodarts.io/detection/${channel}/linux/${arch}/autodarts${version}.linux-${arch}.tar.gz";
      sha256 = "sha256-NbXinthq5ySidy7vB2nmSsX7FzU05tvBxMi8NZfaqCs=";
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [
      glibc
      stdenv.cc.cc.lib
    ];

    sourceRoot = ".";

    unpackPhase = ''
      tar -xzf $src
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp autodarts $out/bin/
      chmod +x $out/bin/autodarts
    '';

    meta = {
      description = "Autodarts board detection service";
      homepage = "https://autodarts.io";
      platforms = ["x86_64-linux" "aarch64-linux" "armv7l-linux"];
    };
  }
