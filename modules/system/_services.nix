{config, ...}: let
  cfg = config.dartkitos;
  is-dev = cfg.environment == "dev";
in {
  config = {
    # ============================================================
    # System services
    # ============================================================
    services.openssh = {
      enable = true;
      settings = {
        # Security: Disable password auth (use keys)
        PasswordAuthentication = is-dev;
        PermitRootLogin = "no";
        # Allow agent forwarding for convenience
        AllowAgentForwarding = true;
      };
    };

    users.users."dartkit".openssh.authorizedKeys.keys = cfg.dev-ssh-keys;

    services = {
      # NTP time sync
      timesyncd.enable = true;

      # Disable unnecessary services for headless operation
      xserver.enable = false;

      # Journal configuration for SD card longevity
      journald.extraConfig = let
        storageValue =
          if is-dev
          then "persistent"
          else "volatile";
      in ''
        Storage=${storageValue}
        # Reduce writes to SD card
        RuntimeMaxUse=64M
        RuntimeMaxFileSize=8M
      '';
    };

    # Nginx reverse proxy - proxy port 80 to 3180
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts."dartkitbox.local" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:3180";
          proxyWebsockets = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [80];

    # mDNS/DNS-SD for local network discovery (dartkitbox.local)
    services.avahi = {
      enable = true;
      nssmdns4 = true; # Enable .local resolution
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    networking.firewall.allowedUDPPorts = [5353];
  };
}
