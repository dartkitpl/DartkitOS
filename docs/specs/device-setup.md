# US-01 Device setup

As a user,
I want to set up my new device without needing a screen or keyboard,
so that I can get it online and register it with the autodarts board.

## UCD-01: Device setup

```mermaid
flowchart LR
    User((User))

    User --> UC1[Power on/off the device]

    User --> UC2[Connect ethernet cable]

    User --> UC3[Trigger device's setup mode by holding the button]

    User --> UC4[Connect to device's hotspot]
    UC4 --> UC5[Fail to authenticate]
    UC4 --> UC6[Authenticate successfully]

    User --> UC7[Register the board in autodarts]

    User --> UC8[Open mDNS URL to reset autodarts registration]
```

## SD-01-US-01: Internet access setup

Preconditions:

- Device is powered on

---

```mermaid
sequenceDiagram
    participant User
    participant Device
    participant Hotspot

    Device->>Device: Boots
    Device->>Device: Check Ethernet
    alt Ethernet connected
        Device-->>User: Online via Ethernet
    end

    opt User wants to use Wi-Fi
        User->>Device: Hold button to setup Wi-Fi
        Device->>+Hotspot: Start AP
        activate Hotspot

        loop until Wi-Fi setup successful
            Hotspot-->>User: Advertise SSID
            User->>Hotspot: Connect via mobile Wi-Fi settings

            Hotspot-->>User: Serve captive portal
            activate User
            User->>User: Open captive portal (automatic or manual)
            User->>Hotspot: Submit Wi-Fi credentials
            deactivate User

            Hotspot->>Device: Attempt Wi-Fi connection
            alt Wi-Fi connection failed
                Device->>Device: Wi-Fi setup failed, continue loop
            else Wi-Fi connection successful
                Device->>Hotspot: Stop AP
                deactivate Hotspot
                Device-->>User: Online via Wi-Fi
            end
        end
    end
```

## SD-02-US-01: Autodarts board registration

Preconditions:

- Device is powered on
- Device is online (via Ethernet or Wi-Fi)

---

```mermaid
sequenceDiagram
    participant User
    participant Autodarts
    participant Device

    User->>Autodarts: Open registration page 
    Autodarts->>Device: Scans for devices on the network 

    opt Device not found
        User->>Device: Open mDNS URL to reset registration
        Device->>Device: Clear registration state
        Device-->>Autodarts: Become discoverable
    end

    Autodarts-->>User: Show device in registration UI
    User->>Autodarts: Select device and submit registration
    Autodarts->>Device: Send registration command
    Device-->>Autodarts: Acknowledge registration
    Autodarts-->>User: Show success message
```

## ST-01-US-01: Hotspot on boot no ethernet

```mermaid
stateDiagram-v2
    [*] --> NotConfigured
    NotConfigured --> Configured: has marker file
    Configured --> [*]

    NotConfigured --> SetupMode: no marker file
    SetupMode --> Configured: setup complete
    SetupMode --> NotConfigured: failed or timeout

    Configured --> NotConfigured: hold button
```

From a user's perspective:

- doing nothing results in:
    1. captive portal showing up when NotConfigured
    2. nothing happening when Configured
- holding a button always results in captive portal showing up

> Doing nothing- inconsistent behavior.
>
> Holding button - consistent behavior.

From a system perspective:

- need to keep track of whether setup has been completed (marker file), so we don't ask user on every boot
- holding the button can happen indeterministically because it's a user action. Thus it needs an always-running event listener

## ST-02-US-01: Hotspot on boot with ethernet

```mermaid
stateDiagram-v2
    [*] --> NotConfigured
    NotConfigured --> Configured: has marker file
    NotConfigured --> Configured: connect ethernet (1)
    Configured --> [*]

    NotConfigured --> SetupMode: no marker file
    SetupMode --> Configured: setup complete
    SetupMode --> Configured: connect ethernet (2)
    SetupMode --> NotConfigured: failed or timeout

    Configured --> NotConfigured: hold button
    Configured --> NotConfigured: disconnect ethernet
```

From a user's perspective:

- doing nothing results in:
    1. captive portal showing up when NotConfigured and no ethernet
    2. nothing happening when NotConfigured and ethernet is connected
    3. nothing happening when Configured

- holding a button results in:
    1. captive portal showing up when no ethernet
    2. nothing happening when ethernet is connected.

- connecting ethernet results in:
    1. nothing happening when NotConfigured or Configured
    2. captive portal turning off when in SetupMode

> Doing nothing- inconsistent behavior
>
> Holding button - inconsistent behavior
>
> Connecting ethernet - inconsistent behavior

From a system perspective:

- need to keep track of whether setup has been completed (marker file), so we don't ask user on every boot
- holding the button can happen indeterministically because it's a user action. Thus it needs an always-running event listener
- ethernet can be connected/disconnected indeterministically because it's a user action. Thus it needs an always-running event listener

> Those two event listeners need to be coordinated such that if either of them triggers, the system transitions to the correct state (complexity)

## ST-03-US-01: Hotspot on button hold regardless of ethernet

```mermaid
stateDiagram-v2
    [*] --> [*]: connect ethernet

    [*] --> SetupMode: hold button
    SetupMode --> [*]: complete, failed or timeout
```

From a user's perspective:

- doing nothing results always in nothing happening
- holding a button always results in captive portal showing up
- connecting ethernet always results in nothing happening

> Doing nothing- consistent behavior
>
> Holding button - consistent behavior
>
> Connecting ethernet - consistent behavior

From a system perspective:

- no internal state is needed to track setup completion, because we don't start at boot
- holding the button can happen indeterministically because it's a user action. Thus it needs an always-running event listener
- ethernet connectivity is managed by the OS and is independent of the wifi setup process

> No internal state simplifies the logic significantly, because we don't have to worry about coordinating between multiple event listeners and edge cases where they might conflict (e.g. user holds button while connecting ethernet)
> The wifi configuration state is managed by the OS, so subsequent boots will just work without needing to track whether setup has been completed or not
> This is the most intuitive from a user's perspective, because the button is a clear and consistent way to trigger setup mode regardless of the network state. It also avoids confusion around why the captive portal might not show up on boot if ethernet is connected.
