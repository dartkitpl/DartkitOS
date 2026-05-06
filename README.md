# DartkitOS

NixOS-based Raspberry Pi images for [Dartkit Boxes](https://dartkit.pl) with Wi-Fi captive portal setup and automatic OTA updates.

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
nix build .#sd-rpi4-prod
```

> **Note:** Choose the package that matches your hardware and environment. Common targets are `.#sd-rpi4-prod`, `.#sd-rpi5-prod`, `.#sd-rpi4-dev`, and `.#sd-rpi5-dev`.
>
> You must have QEMU/binfmt configured if building on x86_64-linux, or a Linux builder if building on aarch64-darwin (Mac).

### Step 3: Flash the SD card

⚠️ **CAUTION:** This will erase the target device!

First, identify your SD card device:

```bash
lsblk
```

Decompress and flash the image (replace `/dev/sdX` with your SD card device):

```bash
zstd -d ./result/sd-image/*.zst -c | sudo dd of=/dev/sdX bs=4M status=progress
```

Ensure all data is written:

```bash
sync
```

Insert the SD card into your Raspberry Pi 4 and power it on.

### Step 4: Connect to Wi-Fi

> [!NOTE]
> Skip this step if you have an Ethernet connection.
>
> [!TIP]
> If you don't yet have a button, you can also trigger the setup portal by:
>
> - running `wifi-setup` manually after SSHing into the device via Ethernet.
> - enabling `dartkitos.wifi-setup.startOnEveryBoot` in the configuration and reflashing (you can disable it once configured- the wifi config will be preserved).
> - connecting correct GPIO pins to simulate the button hold with tweezers or wire.

1. Hold the button on the bottom of the device for 5 seconds
2. Wait till you see the LED pattern indicating the setup AP is active.
3. Connect to Wi-Fi network **`DartkitOS-Setup`** (password: `dartkitos`)
4. Open a browser — you'll be redirected to the captive portal
5. Select your home Wi-Fi network and enter the password
6. Device will apply the settings and connect to your Wi-Fi network

> [!NOTE]
> If you need to reset the Wi-Fi configuration later, hold the button for 5 seconds

## OTA Updates

Devices check for updates every 15 minutes by default. The update flow:

1. Query GitHub Releases API for latest tag
2. Resolve tag to commit SHA
3. Compare with `/etc/dartkitos-version`
4. If different, run `nixos-rebuild switch --flake github:dartkitpl/DartkitOS/<tag>#<config-name>`
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

Rebuild with the **development** configuration matching your hardware (eg. while testing changes locally):

```bash
IP="192.168.1.X"  # replace with device IP
nixos-rebuild switch --flake .#rpi4-dev --build-host localhost --target-host dartkit@$IP --use-remote-sudo
```

> [!NOTE]
> Replace `rpi4-dev` with the appropriate configuration for your device (`nix flake show .` to list all available configurations)
>
> The `*-dev` configurations are tailored for development: they enable SSH access with password authentication (in addition to key-based auth), disable OTA updates, and use more permissive settings (eg. persistent journald storage and non-zero local build jobs). The `*-prod` configurations keep OTA updates enabled and are more locked down.
>
> To get SSH key-based access in dev, add your public key to `dartkitos.dev-ssh-keys` in `configurations/rpi4-dev.nix` and `configurations/rpi5-dev.nix`, for example:
>
> ```nix
> dartkitos.dev-ssh-keys = [
>   "ssh-ed25519 AAAA... your-name@host"
> ];
> ```
>
> Again, binfmt/qemu setup is required if building on x86_64-linux or linux builder if on aarch64-darwin.

## License

MIT
