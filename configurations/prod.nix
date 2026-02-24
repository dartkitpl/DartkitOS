{dartkitosVersion, ...}: {
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
}
