{
  lib,
  config,
  pkgs,
  ...
}: let
  # Target is always Raspberry Pi 4 (aarch64-linux)
  cfg = config.dartkitos.button-handler;
  buttonHandler = pkgs.callPackage ../pkgs/button-handler.nix {};
in {
  options.dartkitos.button-handler = {
    enable = lib.mkEnableOption "daemon for handling GPIO button presses";
  };

  config = lib.mkMerge [
    {
      # Expose the button-handler binary on PATH
      environment.systemPackages = [buttonHandler];
    }
    (lib.mkIf cfg.enable {
      # Create a systemd service to run the button-handler binary
      systemd.services.button-handler = {
        description = "Button Handler Service";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = "${buttonHandler}/bin/button-handler";
          Restart = "always";
          User = "root";
        };
      };
    })
  ];
}
