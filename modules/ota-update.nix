# ============================================================
# ota-update.nix
# ============================================================
# NixOS module for automatic OTA updates of DartkitOS.
#
# How it works:
# 1. A systemd timer fires periodically (default: every 15 minutes)
# 2. The update service checks GitHub Releases for the latest tag
# 3. Compares with /etc/dartkitos-version (stamped at build time)
# 4. If a newer version exists, runs `nixos-rebuild switch --flake`
#    pointing at the tagged flake ref
# 5. All store paths are downloaded from the Attic binary cache —
#    no local compilation happens on the consumer
# 6. If the kernel changed, the system reboots automatically
#
# The version file is written at build time from the flake's
# self.sourceInfo, ensuring it always matches the release tag.
# ============================================================
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dartkitos.ota-update;

  updateScript = pkgs.callPackage ../pkgs/dartkitos-update.nix {};
in {
  # ============================================================
  # Module options
  # ============================================================
  options.dartkitos.ota-update = {
    enable = lib.mkEnableOption "DartkitOS automatic OTA updates";

    githubRepo = lib.mkOption {
      type = lib.types.str;
      default = "dartkitpl/DartkitOS";
      description = "GitHub repository in owner/repo format";
    };

    flakeAttr = lib.mkOption {
      type = lib.types.str;
      default = "dartkitos";
      description = "Name of the nixosConfigurations attribute to build";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15";
      description = ''
        systemd calendar expression for how often to check for updates.
        Default: every 15 minutes.  Examples:
          "*:0/15"    — every 15 minutes
          "hourly"    — once per hour
          "*:0/5"     — every 5 minutes (aggressive, for testing)
      '';
    };

    randomDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = ''
        Random delay in seconds added to each timer tick.
        Prevents all consumers from hitting GitHub/cache simultaneously.
      '';
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "unknown";
      description = ''
        The current version string written to /etc/dartkitos-version.
        This is normally set automatically by the flake via specialArgs.
      '';
    };
  };

  # ============================================================
  # Module implementation
  # ============================================================
  config = lib.mkMerge [
    {
      # ── Stamp the version file at build time ─────────────────────
      environment.etc."dartkitos-version" = {
        text = cfg.version;
        mode = "0444";
      };

      # ── Make the update script available to admins ───────────────
      environment.systemPackages = [updateScript];

      # ── Pass config to the update script via environment ─────────
      environment.sessionVariables = {
        DARTKITOS_FLAKE_ATTR = cfg.flakeAttr;
      };
    }
    (lib.mkIf cfg.enable {
      # ── Systemd service: the actual update job ───────────────────
      systemd.services.dartkitos-update = {
        description = "DartkitOS OTA update check";
        documentation = ["https://github.com/${cfg.githubRepo}"];

        wants = ["network-online.target"];
        after = ["network-online.target"];

        # ── Restart throttling: prevent restart storms ─────────────
        # Max 3 failures per hour — stops infinite restart loops
        startLimitIntervalSec = 3600; # 1 hour
        startLimitBurst = 3;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${updateScript}/bin/dartkitos-update";

          # Pass config as environment
          Environment = [
            "DARTKITOS_GITHUB_REPO=${cfg.githubRepo}"
            "DARTKITOS_FLAKE_ATTR=${cfg.flakeAttr}"
          ];

          # Needs root to run nixos-rebuild switch
          User = "root";

          # Logging
          StandardOutput = "journal";
          StandardError = "journal";
          SyslogIdentifier = "dartkitos-update";

          # Timeouts — rebuilds can take a while downloading
          TimeoutStartSec = "30min";

          # Don't kill the rebuild if it's still running
          KillMode = "process";

          # Retry on transient network failures (with 10min delay to avoid storms)
          Restart = "on-failure";
          RestartSec = "10min";
        };
      };

      # ── Systemd timer: periodic trigger ──────────────────────────
      systemd.timers.dartkitos-update = {
        description = "Periodic DartkitOS OTA update check";
        wantedBy = ["timers.target"];

        timerConfig = {
          OnCalendar = cfg.interval;
          # Spread out requests from the fleet
          RandomizedDelaySec = cfg.randomDelaySec;
          # Run missed checks after sleep/downtime
          Persistent = true;
          # Also run once shortly after boot (give network time to come up)
          OnBootSec = "2min";
        };
      };
    })
  ];
}
