# ============================================================
# wifi-connect.nix
# ============================================================
# This module implements a captive portal for first-boot Wi-Fi configuration.
#
# How it works:
# 1. On boot, if no Wi-Fi is configured, the service starts
# 2. It creates a Wi-Fi access point (AP) named "DartkitOS-Setup"
# 3. Users connect to this AP and are redirected to a captive portal
# 4. They select their home Wi-Fi network and enter the password
# 5. The Pi connects to the configured network
# 6. The AP is automatically shut down
#
# This uses the Balena wifi-connect tool, which is a Rust-based
# captive portal solution specifically designed for IoT devices.
# ============================================================
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.wifi-connect;

  # ============================================================
  # wifi-connect package
  # ============================================================
  # Balena's wifi-connect is the de-facto standard for this use case.
  # We fetch the pre-built aarch64 binary from their releases.
  #
  # NOTE: If the hash is incorrect, run:
  #   nix-prefetch-url https://github.com/balena-os/wifi-connect/releases/download/v4.11.84/wifi-connect-aarch64-unknown-linux-gnu.tar.gz
  # Then convert to SRI format:
  #   nix hash to-sri --type sha256 <hash>
  wifi-connect = pkgs.stdenv.mkDerivation rec {
    pname = "wifi-connect";
    version = "4.11.84";

    src = pkgs.fetchurl {
      url = "https://github.com/balena-os/wifi-connect/releases/download/v${version}/wifi-connect-aarch64-unknown-linux-gnu.tar.gz";
      sha256 = "sha256-QT1w5tHBNmy+KzJVXoR28+koeBeO0bnIIgWYXwVfGTY=";
    };

    # Fetch the UI separately (it's now a separate download)
    ui = pkgs.fetchurl {
      url = "https://github.com/balena-os/wifi-connect/releases/download/v${version}/wifi-connect-ui.tar.gz";
      sha256 = "sha256-5Xo87FWXKVFt7PiSvrHn8ZGyPnGy4TvNQ9NrmAA0/74=";
    };

    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [
      pkgs.glibc
      pkgs.dbus
      pkgs.gcc.cc.lib # Provides libgcc_s.so.1
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
  };

  # ============================================================
  # Helper script to manage wifi-connect lifecycle
  # ============================================================
  # Simple monitor: check connectivity every 30s, start AP if offline.
  wifiConnectScript = pkgs.writeShellScript "wifi-connect-wrapper" ''
    set -u

    AP_SSID="${cfg.apSsid}"
    AP_PASSPHRASE="${cfg.apPassphrase}"
    PORTAL_PORT="${toString cfg.portalPort}"
    WIFI_INTERFACE="${cfg.wifiInterface}"

    log() {
      echo "[wifi-connect] $1"
    }

    has_internet() {
      ${pkgs.curl}/bin/curl -s --max-time 5 http://captive.apple.com/hotspot-detect.html >/dev/null 2>&1
    }

    # Wait for NetworkManager
    sleep 10

    while true; do
      if has_internet; then
        log "Online"
      else
        log "Offline - starting captive portal"
        PATH="${pkgs.dnsmasq}/bin:$PATH" ${wifi-connect}/bin/wifi-connect \
          -s "$AP_SSID" \
          -p "$AP_PASSPHRASE" \
          -o "$PORTAL_PORT" \
          -i "$WIFI_INTERFACE" \
          -u ${wifi-connect}/share/wifi-connect/ui || true
        log "Captive portal exited"
      fi
      sleep 30
    done
  '';
in {
  # ============================================================
  # Module options
  # ============================================================
  options.services.wifi-connect = {
    enable = lib.mkEnableOption "wifi-connect captive portal for first-boot Wi-Fi setup";

    apSsid = lib.mkOption {
      type = lib.types.str;
      default = "DartkitOS-Setup";
      description = "SSID of the setup access point";
    };

    apPassphrase = lib.mkOption {
      type = lib.types.str;
      default = "dartkitos";
      description = "Passphrase for the setup access point (min 8 chars)";
    };

    portalPort = lib.mkOption {
      type = lib.types.port;
      default = 80;
      description = "Port for the captive portal web interface";
    };

    wifiInterface = lib.mkOption {
      type = lib.types.str;
      default = "wlan0";
      description = "Wi-Fi interface to use";
    };

    activityTimeout = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Timeout in seconds for the captive portal (0 = no timeout)";
    };
  };

  # ============================================================
  # Module implementation
  # ============================================================
  config = lib.mkIf cfg.enable {
    # Ensure required packages are available
    environment.systemPackages = [
      wifi-connect
      pkgs.dnsmasq
      pkgs.networkmanager
    ];

    # ============================================================
    # Systemd service for wifi-connect
    # ============================================================
    systemd.services.wifi-connect = {
      description = "WiFi Connect - Captive Portal for Wi-Fi Configuration";
      documentation = ["https://github.com/balena-os/wifi-connect"];

      # Start after NetworkManager is ready
      # We DON'T wait for network-online.target because on first boot
      # with no saved networks, that target might never be reached.
      # Instead, we just wait for NetworkManager to start, then our
      # script will monitor and start the AP if needed.
      after = [
        "NetworkManager.service"
      ];
      wants = [
        "NetworkManager.service"
      ];

      # Continuously run and monitor Wi-Fi connectivity
      serviceConfig = {
        Type = "simple";
        ExecStart = wifiConnectScript;
        User = "root";

        # Always restart to keep the monitor running even if it exits cleanly
        Restart = "always";
        RestartSec = "5s";
      };

      wantedBy = ["multi-user.target"];
    };

    # ============================================================
    # NetworkManager configuration
    # ============================================================
    # Ensure NetworkManager doesn't interfere with the AP
    networking.networkmanager = {
      enable = true;
      # Let wifi-connect manage the wifi interface when in AP mode
      unmanaged = ["interface-name:ap*"];
    };
  };
}
