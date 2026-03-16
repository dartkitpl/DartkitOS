{
  lib,
  config,
  pkgs,
  ...
}: let
  # Target is always Raspberry Pi 4 (aarch64-linux)
  cfg = config.dartkitos.gpio-handlers;
  # Use gpio-handlers built via nixpkgs-25-11 from the overlay.
  gpioHandlers = pkgs.gpioHandlerPackages;
in {
  options.dartkitos.gpio-handlers.button = {
    enable = lib.mkEnableOption "daemon for handling GPIO button presses";
  };

  config = lib.mkMerge [
    {
      # Expose the gpio-handlers binaries on PATH
      environment.systemPackages = [gpioHandlers];
    }
    (lib.mkIf cfg.button.enable {
      # Create a systemd service to run the button-handler binary
      systemd.services.button-handler = {
        description = "Button Handler Service";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        startLimitBurst = 6;
        startLimitIntervalSec = 30;
        path = ["/run/current-system/sw"];
        serviceConfig = {
          ExecStart = "${gpioHandlers}/bin/button-handler";
          Restart = "on-failure";
          RestartSec = "5s";
          User = "root";
        };
      };
    })
  ];
}
