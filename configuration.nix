# ============================================================
# configuration.nix
# ============================================================
# Main NixOS configuration for DartkitOS - a headless Raspberry Pi 4
# image with first-boot Wi-Fi captive portal configuration.
#
# This is a minimal, production-ready configuration focused on:
# - Reliability and stability
# - Minimal attack surface
# - Easy first-time setup via Wi-Fi captive portal
# ============================================================
{
  lib,
  pkgs,
  ...
}: {
  # ============================================================
  # System identification
  # ============================================================
  system.stateVersion = "24.11";

  networking.hostName = "dartkitos";

  # ============================================================
  # Boot configuration for Raspberry Pi 4
  # ============================================================
  boot = {
    # Use the extlinux bootloader (standard for Pi SD images)
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    # Kernel configuration
    kernelParams = [
      # Needed for headless operation - don't wait for graphics
      "console=ttyS1,115200n8"
      "console=tty0"
      # Reduce boot verbosity for production
      "quiet"
      "loglevel=3"
      # Suppress kernel messages to console (but keep in dmesg/journal)
      "consoleblank=0"
      "printk.devkmsg=on"
    ];

    # Set console log level to suppress driver messages
    kernel.sysctl = {
      "kernel.printk" = "3 3 3 3"; # errors only to console
    };

    # Filesystem support
    supportedFilesystems = ["vfat" "ext4"];

    # Enable hardware watchdog for automatic recovery from hangs
    kernelModules = ["bcm2835_wdt"];
  };

  # ============================================================
  # Hardware configuration
  # ============================================================
  hardware = {
    # Enable GPU firmware for headless operation
    raspberry-pi."4" = {
      apply-overlays-dtmerge.enable = true;
      fkms-3d.enable = false; # Headless, no desktop
    };

    # Enable firmware for Wi-Fi and Bluetooth
    enableRedistributableFirmware = true;
    firmware = [pkgs.raspberrypiWirelessFirmware];
  };

  # ============================================================
  # Networking - NetworkManager based
  # ============================================================
  networking = {
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
      allowedUDPPorts = [53 67]; # DNS and DHCP for AP mode
    };
  };

  # ============================================================
  # Enable wifi-connect captive portal
  # ============================================================
  services.wifi-connect = {
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
  services.autodarts = {
    enable = true;
  };

  # ============================================================
  # Time and locale
  # ============================================================
  time.timeZone = "UTC"; # Will be configured by user later

  i18n.defaultLocale = "en_US.UTF-8";

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

  # ============================================================
  # User configuration
  # ============================================================
  users = {
    # Disable mutable users for reproducibility
    # Set mutableUsers = true if you want to change passwords after boot
    mutableUsers = true;

    users.dartkit = {
      isNormalUser = true;
      description = "DartkitOS User";
      extraGroups = [
        "wheel" # sudo access
        "networkmanager" # Network configuration
        "video"
        "gpio" # GPIO access for Pi projects
      ];
      # Default password - CHANGE THIS or use SSH keys
      initialPassword = "dartkit";
      openssh.authorizedKeys.keys = [
        # Add your SSH public key here for secure access
        # "ssh-ed25519 AAAA... user@host"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINmku0qaxDIbYb6MlZEMhqRC0KIdeQoNwIQi6/a4z3Fn mimovnik@glados"
      ];
    };
  };

  # Allow wheel group to use sudo
  security.sudo.wheelNeedsPassword = true;

  # ============================================================
  # System packages
  # ============================================================
  environment.systemPackages = with pkgs; [
    # Essential tools
    vim
    htop
    git
    curl
    wget

    # Network tools
    iproute2
    iputils
    dnsutils
    wirelesstools
    iw

    # System tools
    usbutils
    pciutils
    lsof

    # For GPIO/hardware access
    libraspberrypi
    raspberrypi-eeprom
  ];

  # ============================================================
  # Nix configuration
  # ============================================================
  nix = {
    # Enable flakes
    settings = {
      experimental-features = ["nix-command" "flakes"];
      # Optimize store automatically
      auto-optimise-store = true;
      trusted-users = ["root" "@wheel"];

      # Disable local building to ensure we only use pre-built binaries from our cache
      max-jobs = 0;

      # Prefer downloading over building, even when a derivation could be built locally.
      always-allow-substitutes = true;
      builders-use-substitutes = true;

      # Only accept signed binaries from cache
      require-sigs = true;

      # ── Substituters ──
      # Order matters: try our Attic first, fall back to upstream.
      substituters = [
        "https://cache.dartkit.pl/dartkitos"
        "https://cache.nixos.org/"
      ];

      trusted-substituters = [
        "https://cache.dartkit.pl/dartkitos"
        "https://cache.nixos.org/"
      ];

      trusted-public-keys = [
        "dartkitos:qbEVIC7PCAV2tfg+nUbUT9LqK30r6sdh9vOOcoiag40="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    # No implicit inputs from channels
    registry = {};
    nixPath = [];

    # Garbage collection to save space
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # ============================================================
  # Performance and reliability tweaks for SD card
  # ============================================================
  # Use tmpfs for /tmp to reduce SD card writes
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "256M";

  # Reduce swappiness - SD cards are slow
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };

  # Enable systemd's built-in watchdog
  systemd.watchdog = {
    runtimeTime = "30s";  # Reboot if systemd hangs for 30s
    rebootTime = "3m";    # Force reset if reboot takes more than 3 minutes
  };
}
