# DartkitOS

NixOS-based Raspberry Pi 4 image for [Dartkit Boxes](https://dartkit.pl) with Wi-Fi captive portal setup and automatic OTA updates.

## Features

- **Headless first-boot setup** — Connect to the `DartkitOS-Setup` Wi-Fi AP to configure your network
- **Autodarts integration** — Pre-installed autodarts service with latest/beta channel support
- **Automatic OTA updates** — Devices update themselves from GitHub Releases via binary cache

## First Time Setup

### Step 1: Clone and checkout the latest release

```bash
git clone https://github.com/dartkitpl/DartkitOS.git
cd DartkitOS
```

List available tags

```bash
git tag
```

Check out the latest release tag (replace vX.Y.Z with the latest)

```bash
git checkout vX.Y.Z
```

### Step 2: Build the SD image

```bash
nix build .#sdImage
```

> **Note:** You must have QEMU/binfmt configured if building on x86_64-linux, or a Linux builder if building on aarch64-darwin (Mac).

### Step 3: Flash the SD card

⚠️ **CAUTION:** This will erase the target device!

First, identify your SD card device:

```bash
lsblk
```

Flash the image (replace `/dev/sdX` with your SD card device):

```bash
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress
```

Ensure all data is written:

```bash
sync
```

Insert the SD card into your Raspberry Pi 4 and power it on.

### Step 4: Connect to Wi-Fi (first boot)

> [!NOTE]
> Skip this step if you have an Ethernet connection.

1. Wait ~60 seconds for the setup AP to appear
2. Connect to Wi-Fi network **`DartkitOS-Setup`** (password: `dartkitOS`)
3. Open a browser — you'll be redirected to the captive portal
4. Select your home Wi-Fi network and enter the password
5. The Pi reboots and connects to your network

## OTA Updates

Devices check for updates every 15 minutes by default. The update flow:

1. Query GitHub Releases API for latest tag
2. Resolve tag to commit SHA
3. Compare with `/etc/dartkitos-version`
4. If different, run `nixos-rebuild switch --flake github:dartkitpl/DartkitOS/<tag>`
5. All packages are fetched from the binary cache (no local builds)
6. Reboot if kernel changed

## Development

### Find device on the network

Scan for open 3180 port (used by autodarts) to find the device's IP address:

```bash
nmap -p 3180 --open -oG - 192.168.1.0/24
```

> [!NOTE]
> Adjust the subnet to match your local network (eg. 192.168.3.0/24).

### Commands

Trigger update from releases:

```bash
sudo dartkitos-update
```

Check the current version:

```bash
dartkitos-update --version
```

Rebuild with custom system closure (eg. while testing the configuration):

```bash
IP="192.168.1.X"  # replace with device IP
nixos-rebuild switch --flake .#dartkitos --build-host localhost --target-host dartkit@$IP --use-remote-sudo
```

> [!NOTE]
> This requires SSH access to the device.
> Again, binfmt/qemu setup is required if building on x86_64-linux or linux builder if on aarch64-darwin.

## License

MIT
