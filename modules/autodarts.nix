{getSystem, ...}: {
  flake.nixosModules.autodarts = {
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    cfg = config.dartkitos.autodarts;

    autodarts = (getSystem system).packages.autodarts.override {
      channel = cfg.channel;
    };
  in {
    # ============================================================
    # Module options
    # ============================================================
    options.dartkitos.autodarts = {
      enable = lib.mkEnableOption "autodarts board detection service";

      channel = lib.mkOption {
        type = lib.types.enum ["latest" "beta"];
        default = "latest";
        description = "Release channel to use (latest or beta)";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "autodarts";
        description = "User account under which autodarts runs";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "autodarts";
        description = "Group under which autodarts runs";
      };

      configDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/autodarts";
        description = "Directory for autodarts configuration and data";
      };
    };

    # ============================================================
    # Module implementation
    # ============================================================
    config = lib.mkIf cfg.enable {
      # Create the autodarts user and group
      users.users.${cfg.user} = lib.mkIf (cfg.user == "autodarts") {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.configDir;
        createHome = true;
        description = "Autodarts service user";
        extraGroups = ["video"]; # Access to camera devices
      };

      users.groups.${cfg.group} = lib.mkIf (cfg.group == "autodarts") {};

      # Ensure config directory exists with proper permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.configDir} 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.configDir}/.config 0750 ${cfg.user} ${cfg.group} -"
        "d ${cfg.configDir}/.config/autodarts 0750 ${cfg.user} ${cfg.group} -"
      ];

      # ============================================================
      # Main autodarts service
      # ============================================================
      systemd.services.autodarts = {
        description = "Autodarts board detection service";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target" "time-sync.target"];
        after = ["network.target" "network-online.target" "systemd-tmpfiles-setup.service" "time-sync.target"];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.configDir;
          Environment = [
            "HOME=${cfg.configDir}"
            "XDG_CONFIG_HOME=${cfg.configDir}/.config"
          ];

          # Wait for network connectivity before starting
          ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.iputils}/bin/ping -c1 get.autodarts.io; do echo waiting for internet; sleep 1; done;'";
          ExecStart = "${autodarts}/bin/autodarts";

          Restart = "on-failure";
          RestartSec = "1s";
          KillSignal = "SIGINT";

          LogLevelMax = "warning";

          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ReadWritePaths = [cfg.configDir];
        };
      };

      # Open autodarts web ports
      networking.firewall.allowedTCPPorts = [3180 3181];

      # Make the autodarts package available system-wide
      environment.systemPackages = [autodarts];
    };
  };
}
