# ============================================================
# autodarts.nix
# ============================================================
# This module packages the autodarts binary and sets up a systemd service
# for the main autodarts application.
#
# Features:
# - Downloads and installs the autodarts binary for the target architecture
# - Creates a systemd service for autodarts to start on boot
# - Supports latest and beta channels
# ============================================================
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.autodarts;

  # Architecture mapping for autodarts downloads
  archMap = {
    "x86_64-linux" = "amd64";
    "aarch64-linux" = "arm64";
    "armv7l-linux" = "armv7l";
  };

  arch = archMap.${pkgs.system} or (throw "Unsupported architecture: ${pkgs.system}");

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
  autodarts = pkgs.stdenv.mkDerivation rec {
    pname = "autodarts";
    version = "1.0.4";

    src = pkgs.fetchurl {
      url = "https://get.autodarts.io/detection/${cfg.channel}/linux/${arch}/autodarts${version}.linux-${arch}.tar.gz";
      sha256 = "sha256-NbXinthq5ySidy7vB2nmSsX7FzU05tvBxMi8NZfaqCs=";
    };

    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [
      pkgs.glibc
      pkgs.stdenv.cc.cc.lib
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
  };
in {
  # ============================================================
  # Module options
  # ============================================================
  options.services.autodarts = {
    enable = lib.mkEnableOption "autodarts board detection service";

    channel = lib.mkOption {
      type = lib.types.enum ["latest" "beta"];
      default = "latest";
      description = "Release channel to use (latest or beta)";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "autodarts";
      description = "User account under which autodarts runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "autodarts";
      description = "Group under which autodarts runs";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/autodarts";
      description = "Directory for autodarts configuration and data";
    };
  };

  # ============================================================
  # Module implementation
  # ============================================================
  config = lib.mkIf cfg.enable {
    # Create the autodarts user and group
    users.users.${cfg.user} = lib.mkIf (cfg.user == "autodarts") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.configDir;
      createHome = true;
      description = "Autodarts service user";
      extraGroups = ["video"]; # Access to camera devices
    };

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "autodarts") {};

    # Ensure config directory exists with proper permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.configDir}/.config 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.configDir}/.config/autodarts 0750 ${cfg.user} ${cfg.group} -"
    ];

    # ============================================================
    # Main autodarts service
    # ============================================================
    systemd.services.autodarts = {
      description = "Autodarts board detection service";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target" "time-sync.target"];
      after = ["network.target" "network-online.target" "systemd-tmpfiles-setup.service" "time-sync.target"];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.configDir;
        Environment = [
          "HOME=${cfg.configDir}"
          "XDG_CONFIG_HOME=${cfg.configDir}/.config"
        ];

        # Wait for network connectivity before starting
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.iputils}/bin/ping -c1 get.autodarts.io; do echo waiting for internet; sleep 1; done;'";
        ExecStart = "${autodarts}/bin/autodarts";

        Restart = "on-failure";
        RestartSec = "1s";
        KillSignal = "SIGINT";

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [cfg.configDir];
      };
    };

    # Make the autodarts package available system-wide
    environment.systemPackages = [autodarts];
  };
}
