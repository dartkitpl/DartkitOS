{
  networking = {
    hostName = "dartkitbox";
    # Use NetworkManager as the primary network manager
    # This is required for wifi-connect to work properly
    networkmanager = {
      enable = true;
      # Enable Wi-Fi by default
      wifi.powersave = false; # Disable power save for reliability
    };

    # Disable other network management to avoid conflicts
    useDHCP = false; # Let NetworkManager handle DHCP
    wireless.enable = false; # We use NetworkManager, not wpa_supplicant

    # Basic firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };
}
