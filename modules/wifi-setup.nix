{getSystem, ...}: {
  flake.nixosModules.wifiSetup = {
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    cfg = config.dartkitos.wifi-setup;

    wifi-connect = (getSystem system).packages.wifi-connect;

    dependentServices = "nginx avahi-daemon";

    wifiSetupScript = pkgs.writeShellScriptBin "wifi-setup" ''
      set -eu

      DEPENDENT_SERVICES="${dependentServices}"
      LED_CMD="${cfg.ledCmd}"

      AP_SSID="${cfg.apSsid}"
      AP_PASSPHRASE="${cfg.apPassphrase}"
      PORTAL_PORT="${toString cfg.portalPort}"
      WIFI_INTERFACE="${cfg.wifiInterface}"

      this_cmd="$(basename "$0")"

      if [[ "''${1:-}" == "-h" || "''${1:-}" == "--help" ]]; then
        echo "Usage: $this_cmd"
        echo "Starts a captive portal for Wi-Fi setup."
        exit 0
      fi

      log() {
        echo "[$this_cmd] $1"
      }

      if [ "$(id -u)" -ne 0 ]; then
        log "Error: $this_cmd must be run as root"
        exit 1
      fi

      cleanup() {
        pkill $LED_CMD || true
        $LED_CMD off || true
      }

      trap cleanup EXIT

      $LED_CMD on &

      log "Setting up Wi-Fi configuration..."

      for service in $DEPENDENT_SERVICES; do
        log "Stopping $service..."
        ${pkgs.systemd}/bin/systemctl stop "$service.socket" 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl stop "$service.service" || log "Warning: failed to stop $service"
      done

      log "Waiting for NetworkManager startup..."
      ${pkgs.networkmanager}/bin/nm-online -s -q -t 30 || true

      log "Starting captive portal for Wi-Fi configuration"
      $LED_CMD blink &

      PATH="${pkgs.dnsmasq}/bin:$PATH" ${wifi-connect}/bin/wifi-connect \
        -s "$AP_SSID" \
        -p "$AP_PASSPHRASE" \
        -o "$PORTAL_PORT" \
        -i "$WIFI_INTERFACE" \
        -u ${wifi-connect}/share/wifi-connect/ui

      log "Wi-Fi configured successfully"

      # Blink fast a few times to indicate success, then turn off
      cleanup
      $LED_CMD blink --duration 100 --count 3 &

      for service in $DEPENDENT_SERVICES; do
        log "Starting $service..."
        ${pkgs.systemd}/bin/systemctl start "$service.service" || log "Warning: failed to start $service"
      done

      log "Wi-Fi reset complete"
      cleanup
    '';
  in {
    options.dartkitos.wifi-setup = {
      enable = lib.mkEnableOption "wifi-connect captive portal for first-boot Wi-Fi setup";

      startOnEveryBoot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Start the Wi-Fi setup portal on every boot";
      };

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
        default = 15 * 60;
        description = "Timeout in seconds for the captive portal (0 = no timeout)";
      };

      ledCmd = lib.mkOption {
        type = lib.types.str;
        default = "led-handler";
        description = "Command to control the LED for status indication";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        wifi-connect
        pkgs.dnsmasq
        pkgs.networkmanager
        wifiSetupScript
      ];

      systemd.services.wifi-setup = lib.mkIf cfg.startOnEveryBoot {
        description = "Wi-Fi Setup - Captive Portal every boot";
        # Start after NetworkManager is ready
        after = [
          "NetworkManager.service"
        ];
        wants = [
          "NetworkManager.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${wifiSetupScript}/bin/wifi-setup";
          User = "root";
          RemainAfterExit = true;
        };

        wantedBy = ["multi-user.target"];
      };

      networking.networkmanager = {
        enable = true;
        # Let wifi-connect manage the wifi interface when in AP mode
        unmanaged = ["interface-name:ap*"];
      };
    };
  };
}
