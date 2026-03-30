{getSystem, ...}: {
  flake.nixosModules.gpioHandlers = {
    lib,
    config,
    system,
    ...
  }: let
    cfg = config.dartkitos.gpio-handlers;

    gpioHandlers = (getSystem system).packages.gpio-handlers;
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
  };
}
