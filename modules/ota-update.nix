{
  self,
  getSystem,
  ...
}: {
  flake.nixosModules.otaUpdate = {
    config,
    lib,
    system,
    ...
  }: let
    cfg = config.dartkitos.ota-update;

    updateScript = (getSystem system).packages.dartkitos-update;
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
    };

    # ============================================================
    # Module implementation
    # ============================================================
    config = lib.mkMerge [
      {
        # ── Stamp the version file at build time ─────────────────────

        # Derive version from the flake's source info.
        # - self.rev: full commit SHA from a clean git checkout or github: flake ref
        # - self.dirtyRev: commit SHA + "-dirty" when there are uncommitted changes
        # - "non-git": fallback when built from tarball/zip without .git directory

        # The OTA update script compares this against the commit SHA
        # associated with the latest GitHub Release tag.
        environment.etc."dartkitos-version" = {
          text =
            if self ? rev
            then self.rev
            else if self ? dirtyRev
            then self.dirtyRev
            else "non-git";

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
  };
}
