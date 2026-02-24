{
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.nixosModules.raspberry-pi-4
  ];

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
  # Time and locale
  # ============================================================
  time.timeZone = "UTC"; # Will be configured by user later

  i18n.defaultLocale = "en_US.UTF-8";

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
    runtimeTime = "30s"; # Reboot if systemd hangs for 30s
    rebootTime = "3m"; # Force reset if reboot takes more than 3 minutes
  };

  # ============================================================
  # System identification
  # ============================================================
  system.stateVersion = "24.11";
}
