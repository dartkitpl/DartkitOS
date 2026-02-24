{lib, ...}: {
  # ============================================================
  # System services
  # ============================================================
  services = {
    # Enable SSH for remote access after initial setup
    openssh = {
      enable = true;
      settings = {
        # Security: Disable password auth (use keys)
        PasswordAuthentication = lib.mkDefault true; # Enable for first setup
        PermitRootLogin = "prohibit-password";
        # Allow agent forwarding for convenience
        AllowAgentForwarding = true;
      };
    };

    # NTP time sync
    timesyncd.enable = true;

    # Disable unnecessary services for headless operation
    xserver.enable = false;

    # Journal configuration for SD card longevity
    journald = {
      extraConfig = ''
        Storage=persistent
        # Reduce writes to SD card
        RuntimeMaxUse=64M
        RuntimeMaxFileSize=8M
      '';
    };
  };

  # Nginx reverse proxy - proxy port 80 to 3180
  # Only starts after wifi-setup has completed (marker file exists)
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

  systemd.services.nginx = {
    after = ["wifi-setup.service"];
    requires = ["wifi-setup.service"];
    # Only start if setup has been completed
    unitConfig.ConditionPathExists = "/var/lib/wifi-connect/setup-complete";
  };

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

  systemd.services.avahi-daemon = {
    after = ["wifi-setup.service"];
    requires = ["wifi-setup.service"];
    unitConfig.ConditionPathExists = "/var/lib/wifi-connect/setup-complete";
  };
}
