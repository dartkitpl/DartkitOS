{
  dartkitos.wifi-setup = {
    enable = true;
    apSsid = "DartkitOS-Setup-dev";
    apPassphrase = "dartkitos";
    portalPort = 80;
    wifiInterface = "wlan0";
    activityTimeout = 0; # No timeout - wait forever for user
  };

  dartkitos.autodarts.enable = true;

  dartkitos.ota-update.enable = false;
}
