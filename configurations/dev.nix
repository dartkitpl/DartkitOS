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
}
