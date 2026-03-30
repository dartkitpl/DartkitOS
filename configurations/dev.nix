{
  inputs,
  self,
  ...
}: let
  system = "aarch64-linux";
  configName = "dev";
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

      {
        dartkitos.environment = "dev";
        dartkitos.dev-ssh-keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINmku0qaxDIbYb6MlZEMhqRC0KIdeQoNwIQi6/a4z3Fn mimovnik@glados"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZa/wODfmLrSRXkZXnQoaIRNsdOg73q/DWeiev6VuF+ szymongr14@gmail.com"
        ];

        dartkitos.wifi-setup = {
          enable = true;
          apSsid = "DartkitOS-Setup-dev";
          apPassphrase = "dartkitos";
          portalPort = 80;
          wifiInterface = "wlan0";
          activityTimeout = 0; # No timeout - wait forever for user
        };

        dartkitos.autodarts.enable = true;

        dartkitos.ota-update = {
          enable = false;
          flakeAttr = "dev";
        };

        dartkitos.gpio-handlers.button.enable = true;
      }
    ];
  };
}
