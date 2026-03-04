# ============================================================
# wifi-connect.nix
# ============================================================
# This module implements a one-time captive portal for first-time Wi-Fi setup.
#
# How it works:
# 1. On first boot (ever), the service starts the captive portal
# 2. It creates a Wi-Fi access point (AP) named "DartkitOS-Setup"
# 3. Users connect to this AP and are redirected to a captive portal
# 4. They select their home Wi-Fi network and enter the password
# 5. The Pi connects to the configured network
# 6. A marker file is created to indicate setup is complete
# 7. The service never runs again (one-time setup per device lifetime)
#
# This uses the Balena wifi-connect tool, which is a Rust-based
# captive portal solution specifically designed for IoT devices.
#
# To re-run first-time setup, delete /var/lib/wifi-connect/setup-complete
# ============================================================
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dartkitos.wifi-setup;

  # Import wifi-connect package from pkgs/
  wifi-connect = pkgs.callPackage ../pkgs/wifi-connect.nix {};

  # Marker file location - persists across reboots
  setupCompleteMarker = "/var/lib/wifi-connect/setup-complete";

  # ============================================================
  # Wi-Fi reset script
  # ============================================================
  # Resets the Wi-Fi configuration by stopping dependent services,
  # removing the setup marker file, and restarting the wifi-setup service.
  # This is called by the button-handler when the reset button is held.
  # Services that depend on wifi setup being complete
  # These need to be stopped before reset and started after wifi-setup completes
  dependentServices = "nginx avahi-daemon";

  wifiResetScript = pkgs.writeShellScriptBin "wifi-reset" ''
    set -eu

    MARKER_FILE="${setupCompleteMarker}"
    DEPENDENT_SERVICES="${dependentServices}"

    log() {
      echo "[wifi-reset] $1"
    }

    # This script must run as root
    if [ "$(id -u)" -ne 0 ]; then
      log "Error: wifi-reset must be run as root"
      exit 1
    fi

    log "Resetting Wi-Fi configuration..."

    # Stop dependent services first (including sockets if they exist to avoid auto-restart)
    for service in $DEPENDENT_SERVICES; do
      log "Stopping $service..."
      ${pkgs.systemd}/bin/systemctl stop "$service.socket" 2>/dev/null || true
      ${pkgs.systemd}/bin/systemctl stop "$service.service" || log "Warning: failed to stop $service"
    done

    # Remove the marker file so wifi-setup thinks it's a fresh install
    log "Removing setup marker file..."
    rm -f "$MARKER_FILE"

    # Restart wifi-setup service to launch the captive portal
    # This blocks until wifi configuration is complete
    log "Restarting wifi-setup service..."
    ${pkgs.systemd}/bin/systemctl restart wifi-setup

    # After wifi-setup completes (marker file created), start dependent services
    log "Starting dependent services..."
    for service in $DEPENDENT_SERVICES; do
      log "Starting $service..."
      ${pkgs.systemd}/bin/systemctl start "$service.service" || log "Warning: failed to start $service"
    done

    log "Wi-Fi reset complete"
  '';

  # ============================================================
  # Wi-Fi setup script
  # ============================================================
  # Runs ONCE per device lifetime. Creates marker file on success.
  wifiSetupScript = pkgs.writeShellScriptBin "wifi-setup" ''
    set -eu

    AP_SSID="${cfg.apSsid}"
    AP_PASSPHRASE="${cfg.apPassphrase}"
    PORTAL_PORT="${toString cfg.portalPort}"
    WIFI_INTERFACE="${cfg.wifiInterface}"
    MARKER_FILE="${setupCompleteMarker}"

    log() {
      echo "[wifi-setup] $1"
    }

    # Check if setup was already completed
    if [ -f "$MARKER_FILE" ]; then
      log "Setup already completed. Exiting."
      exit 0
    fi

    log "Wi-Fi setup starting..."

    # Ensure state directory exists
    mkdir -p "$(dirname "$MARKER_FILE")"

    # Wait for NetworkManager to finish starting
    log "Waiting for NetworkManager startup..."
    ${pkgs.networkmanager}/bin/nm-online -s -q -t 30 || true

    log "Starting captive portal for Wi-Fi configuration"
    PATH="${pkgs.dnsmasq}/bin:$PATH" ${wifi-connect}/bin/wifi-connect \
      -s "$AP_SSID" \
      -p "$AP_PASSPHRASE" \
      -o "$PORTAL_PORT" \
      -i "$WIFI_INTERFACE" \
      -u ${wifi-connect}/share/wifi-connect/ui

    # wifi-connect exits with 0 when user successfully configures Wi-Fi
    log "Wi-Fi configured successfully. Marking setup as complete."
    echo "Setup completed on $(date -Iseconds)" >> "$MARKER_FILE"

    log "Wi-Fi setup finished."
  '';
in {
  # ============================================================
  # Module options
  # ============================================================
  options.dartkitos.wifi-setup = {
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
      wifiSetupScript
      wifiResetScript
    ];

    # ============================================================
    # Systemd service for Wi-Fi setup
    # ============================================================
    systemd.services.wifi-setup = {
      description = "Wi-Fi Setup - Captive Portal";
      documentation = ["https://github.com/balena-os/wifi-connect"];

      # Start after NetworkManager is ready
      after = [
        "NetworkManager.service"
      ];
      wants = [
        "NetworkManager.service"
      ];

      # One-shot service - runs once and exits
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${wifiSetupScript}/bin/wifi-setup";
        User = "root";
        # RemainAfterExit=true so dependent services can use After=wifi-setup.service
        RemainAfterExit = true;

        # State directory for marker file
        StateDirectory = "wifi-connect";
      };

      # Only run on boot, but the script itself checks the marker file
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
