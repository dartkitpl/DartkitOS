{
  inputs,
  self,
  ...
}: let
  system = "aarch64-linux";
  configName = "rpi5-prod";
in {
  flake.nixosConfigurations.${configName} = inputs.nixos-raspberrypi.lib.nixosSystem {
    nixpkgs = inputs.nixpkgs-25-11;
    inherit system;

    specialArgs = {
      inherit system;
      inherit (inputs) nixpkgs nixpkgs-25-11;
    };

    modules = [
      self.nixosModules.rpi5
      self.nixosModules.dartkitosBase

      {
        dartkitos.environment = "prod";

        # ============================================================
        # Enable wifi-setup captive portal
        # ============================================================
        dartkitos.wifi-setup = {
          enable = true;
          apSsid = "DartkitOS-Setup";
          apPassphrase = "dartkitos"; # Change this for production!
          portalPort = 80;
          wifiInterface = "wlan0";
          activityTimeout = 0; # No timeout - wait forever for user
        };

        # ============================================================
        # Enable autodarts board detection service
        # ============================================================
        dartkitos.autodarts.enable = true;

        # ============================================================
        # OTA updates from GitHub Releases + Attic binary cache
        # ============================================================
        dartkitos.ota-update = {
          enable = true;
          githubRepo = "dartkitpl/DartkitOS"; # default
          interval = "*:0/15"; # every 15 min (default)
          randomDelaySec = 120; # stagger fleet (default)
          flakeAttr = configName;
        };

        dartkitos.gpio-handlers.button.enable = true;
      }
    ];
  };
}
