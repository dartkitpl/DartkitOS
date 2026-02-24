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
      # Allow captive portal HTTP, DNS, autodarts setup
      allowedTCPPorts = [80 53 3180 3181];
      allowedUDPPorts = [53 67 5353]; # DNS, DHCP for AP mode, mDNS
    };
  };
}
