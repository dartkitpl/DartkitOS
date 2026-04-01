{pkgs, ...}: {
  # ============================================================
  # Boot configuration
  # ============================================================
  boot = {
    # Filesystem support
    supportedFilesystems = ["vfat" "ext4"];
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
    wirelesstools
    iw

    # System tools
    usbutils
    pciutils
    lsof
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
