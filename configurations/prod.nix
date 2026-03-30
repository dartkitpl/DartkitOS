{
  inputs,
  self,
  ...
}: let
  system = "aarch64-linux";
  configName = "dartkitos";
in {
  flake.nixosConfigurations.${configName} = inputs.nixpkgs.lib.nixosSystem {
    inherit system;

    specialArgs = {
      inherit system;
      inherit (inputs) nixos-hardware nixpkgs nixpkgs-25-11;

      # Derive version from the flake's source info.
      # - self.rev: full commit SHA from a clean git checkout or github: flake ref
      # - self.dirtyRev: commit SHA + "-dirty" when there are uncommitted changes
      # - "non-git": fallback when built from tarball/zip without .git directory

      # The OTA update script compares this against the commit SHA
      # associated with the latest GitHub Release tag.
      dartkitosVersion =
        if self ? rev
        then self.rev
        else if self ? dirtyRev
        then self.dirtyRev
        else "non-git";
    };

    modules = [
      self.nixosModules.dartkitosBase

      ({dartkitosVersion, ...}: {
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
          version = dartkitosVersion;
          githubRepo = "dartkitpl/DartkitOS"; # default
          interval = "*:0/15"; # every 15 min (default)
          randomDelaySec = 120; # stagger fleet (default)
        };

        dartkitos.gpio-handlers.button.enable = true;
      })
    ];
  };
}
