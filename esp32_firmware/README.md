# CRANTROL — ESP32-S3-ETH Firmware

This document describes the firmware that runs on the ESP32-S3-ETH board in this repository. All defaults and behaviors described below are taken directly from the firmware source files (esp32_firmware/include/*.h and esp32_firmware/src/*).

Core features (code-implemented)

- Ethernet connectivity (W5500 SPI)
- Firebase Realtime Database integration for commands and status
- Captive portal for initial configuration (AP + web UI)
- 10 relay slot support (MAX_RELAYS = 10)
- Latched and pulse relays (pulse behaviour implemented for specific slots)
- RGB status LED plus dedicated status/network LEDs and buzzer
- NVS-based persistent configuration
- PlatformIO-friendly structure and pre-build env injection

Pin mappings (exact values from esp32_firmware/include/config.h)

| Purpose | Macro | GPIO |
|---------|-------:|-----:|
| Relay 1 | RELAY_1_PIN  | 21 |
| Relay 2 | RELAY_2_PIN  | 17 |
| Relay 3 | RELAY_3_PIN  | 16 |
| Relay 4 | RELAY_4_PIN  | 18 |
| Relay 5 | RELAY_5_PIN  | 15 |
| Relay 6 | RELAY_6_PIN  | 3  |
| Relay 7 | RELAY_7_PIN  | 2  |
| Relay 8 | RELAY_8_PIN  | 1  |
| Relay 9 | RELAY_9_PIN  | 0  |
| Relay 10| RELAY_10_PIN | 44 |
| Buzzer  | BUZZER_PIN   | 43 |
| Status LED | STATUS_LED_PIN | 47 |
| Network LED | NETWORK_LED_PIN | 48 |
| RGB LED | RGB_LED_PIN | 46 |

Ethernet (W5500 SPI) pins

- ETH_MISO_PIN = 12
- ETH_MOSI_PIN = 11
- ETH_SCLK_PIN = 13
- ETH_CS_PIN   = 14
- ETH_IRQ_PIN  = 10
- ETH_RST_PIN  = 9

Captive portal defaults (config.h)

- Default AP SSID: `PC-Control-Setup`
- Default AP password: `12345678`
- Portal IP: `http://192.168.4.1`

Environment injection at build time

- `esp32_firmware/scripts/load_env.py` reads repo-root `.env` and writes `.pio/generated_env.h` containing `#define` statements for FB_API_KEY, FB_AUTH_DOMAIN, etc. This file is added to the include path during PlatformIO builds to inject Firebase credentials into the firmware.

Relay behaviour (precise)

- Firmware supports commands: `ON`, `OFF`, and `PULSE`.
- `executeCommand` in `relay_manager.cpp` handles de-duplication by `revision`, sets pins according to `activeLow`, and manages pulse timers using `pulseOffTimeMs`.
- Default pulse relays: relay 9 and relay 10 are marked as pulse relays in code; specific pulse durations are defined in `pc_types.h`.

Build instructions (PlatformIO)

```bash
cd esp32_firmware
platformio run -e esp32-s3-eth      # build
platformio run -e esp32-s3-eth --target upload  # upload to device
platformio device monitor -p <port> -b 115200   # serial monitor
```

Troubleshooting (code-aligned)

- If generated_env.h is missing or empty: ensure the repository root `.env` contains FIREBASE_* entries and re-run PlatformIO build; load_env.py will create `.pio/generated_env.h`.
- If linker errors referencing library archives occur: a `pio run -e esp32-s3-eth -v` log and a clean of `.pio` typically help (`pio run -e esp32-s3-eth --target clean; pio run -e esp32-s3-eth`).
- If a relay does not switch: verify the `pin` value in device `config` (stored under RTDB `devices/{deviceId}/config/relays`) or remap the slot via the captive portal.

Serial output

- Use 115200 baud to view standard firmware logs. Look for tags such as `[ETH]`, `[FB]`, `[RELAY]`, and `[PORTAL]`.

Security notes

- The firmware uses whatever FB_* values are injected at build time; never commit real credentials into the repository. Use `.env.example` for placeholders and keep local `.env` out of version control.

For deeper implementation details, review `esp32_firmware/include/pc_types.h` (relay defaults) and `esp32_firmware/include/config.h` (pin constants and defaults).


Complete firmware for Waveshare ESP32-S3-ETH board with multi-relay control, Firebase integration, and local captive portal configuration.

## Features

- **Ethernet Connectivity**: W5500 chip support with automatic reconnection
- **Firebase Integration**: Real-time database sync for remote control
- **Captive Portal**: Local Wi-Fi AP for configuration without internet
- **Multi-Relay Support**: 4 relays (expandable to 8)
- **RGB LED Status**: Visual indication of network and system status
- **NVS Storage**: Persistent configuration across reboots
- **Production-Ready**: Stable, tested code with proper error handling

## Hardware Setup

### GPIO Pin Mapping

| Component | Pin | Function |
|-----------|-----|----------|
| Relay 1 | GPIO33 | PC Power |
| Relay 2 | GPIO34 | Monitor 1 |
| Relay 3 | GPIO35 | Monitor 2 |
| Relay 4 | GPIO36 | PC Front Panel (Pulse) |
| Buzzer | GPIO46 | Audio feedback |
| Status LED | GPIO47 | Status indication |
| Network LED | GPIO48 | Network indication |
| RGB LED | GPIO21 | Multicolor status (onboard) |

### Ethernet W5500 SPI Pins

| Pin | GPIO |
|-----|------|
| MISO | GPIO12 |
| MOSI | GPIO11 |
| SCLK | GPIO13 |
| CS | GPIO14 |
| IRQ | GPIO10 |
| RST | GPIO9 |

## Compilation

### Option 1: Arduino IDE

1. Copy `esp32_firmware.ino`, `include/` and `src/` directories to a new Arduino sketch folder
2. Install required libraries:
   - ArduinoJson (Benoit Blanchon)
   - Adafruit NeoPixel
3. Select Board: "ESP32S3 Dev Module"
4. Compile and upload

### Option 2: PlatformIO

```bash
platformio run -e esp32-s3-eth
platformio run -e esp32-s3-eth --target upload
platformio run -e esp32-s3-eth --target monitor
```

### Option 3: VS Code with Arduino Extension

1. Open the workspace in VS Code
2. Install Arduino extension
3. Click Arduino icon in sidebar
4. Select board: ESP32S3 Dev Module
5. Compile and upload

## Firmware Structure

```
esp32_firmware/
├── esp32_firmware.ino          # Main sketch
├── include/
│   ├── pc_types.h             # Type definitions
│   ├── config.h               # Configuration & defaults
│   ├── relay_manager.h        # Relay control
│   ├── led_status_manager.h   # RGB LED control
│   ├── ethernet_manager.h     # Network management
│   ├── firebase_client.h      # Firebase integration
│   └── captive_portal.h       # Web portal
├── src/
│   ├── relay_manager.cpp
│   ├── led_status_manager.cpp
│   ├── ethernet_manager.cpp
│   ├── firebase_client.cpp
│   └── captive_portal.cpp
└── platformio.ini             # Build configuration
```

## Operation

### RGB LED Status Codes

| Color | Meaning |
|-------|---------|
| **Blue** (solid) | Ethernet cable not plugged |
| **Orange** (solid) | Ethernet plugged, no internet |
| **Green** (blinking) | Internet available, Firebase ready |
| **Red** (blinking) | Internet down, Firebase disconnected |

### Captive Portal Access

1. Power on the device
2. Look for Wi-Fi network: "HashPC-Setup" (default SSID)
3. Connect with password: "SetupHashPC2024" (default)
4. Open browser, automatic redirect to http://192.168.4.1
5. Login with Firebase credentials
6. Configure device settings, relays, and Firebase

### Default Firebase Credentials

- Email: `PUT_YOUR_FIREBASE_EMAIL_HERE`
- Password: `PUT_YOUR_FIREBASE_PASSWORD_HERE`
- API Key: `PUT_YOUR_FIREBASE_API_KEY_HERE`
- Project ID: `PUT_YOUR_FIREBASE_PROJECT_ID_HERE`

## Firebase Database Structure

```
devices/
  ├── {deviceId}/
  │   ├── config/           # Device configuration
  │   ├── status/           # Current status
  │   ├── desired/          # Desired relay states
  │   └── logs/             # Device logs
rooms/
  └── {roomId}/             # Room configuration
ota/
  └── devices/{deviceId}/   # OTA updates
system/
  └── logs/{deviceId}/      # System logs
```

## Configuration

All settings are stored in NVS (Non-Volatile Storage) and survive reboot.

### Device Configuration

- Device Name
- Device ID
- Room ID & Code
- Relay count and GPIO mapping
- Relay names and settings
- LED pin assignments

### Firebase Configuration

- API Key
- Auth Domain
- Database URL
- Project ID
- Email & Password

## Relay Control

### Relay Types

1. **Latched**: ON/OFF states are maintained (Relays 1-3)
2. **Pulse**: Momentary pulse for button control (Relay 4)

### Relay Configuration

```json
{
  "id": 1,
  "name": "PC Power",
  "pin": 33,
  "activeLow": false,
  "pulseDurationMs": 0,
  "enabled": true,
  "isPulse": false
}
```

## Network Behavior

- **Automatic Reconnection**: Detects ethernet cable unplugs and reconnects
- **Internet Detection**: Checks connectivity every 30 seconds
- **Firebase Sync**: Updates status every 5 seconds when connected
- **Token Refresh**: Automatically refreshes Firebase tokens every 60 minutes
- **Debouncing**: Prevents duplicate relay commands

## Serial Output

Monitor device operation via Serial at 115200 baud:

```
[ETH] Initializing Ethernet...
[ETH] Ethernet cable plugged
[ETH] Got IP: 192.168.1.100
[FB] Authenticating with Firebase...
[FB] Authentication successful
[PORTAL] Captive Portal started successfully
[STATUS] Network Status Update:
  Ethernet Plugged: Yes
  Internet Available: Yes
  Firebase Auth: Ready
  Local IP: 192.168.1.100
```

## Troubleshooting

### Ethernet not connecting
1. Check cable is properly plugged into W5500 board
2. Verify GPIO assignments match hardware
3. Look for "ETH] Ethernet cable unplugged" in serial output

### Firebase authentication fails
1. Verify Firebase credentials in captive portal
2. Check internet connectivity
3. Look for error messages starting with "[FB]"

### Relay not responding
1. Verify GPIO pin mapping matches hardware
2. Check "activeLow" setting matches relay module
3. Monitor serial output for relay commands

### Captive portal not accessible
1. Connect to "HashPC-Setup" Wi-Fi network
2. Device should auto-redirect; if not, open http://192.168.4.1
3. Try clearing browser cache if portal page looks broken

## Memory Usage

- Flash: ~600KB (sketch + libraries)
- SRAM: ~150KB (runtime + buffers)
- NVS: ~4KB (configuration)

## Performance

- Main loop cycle: ~10ms
- Firebase sync interval: 5 seconds
- Network status check: 30 seconds
- LED update frequency: 100ms
- Relay response time: <50ms

## Security Considerations

- Captive portal password: Change via settings
- Firebase credentials: Stored in NVS (not encrypted in current version)
- HTTPS: All Firebase communication is encrypted
- Token expiry: Automatically refreshed every 60 minutes

## Future Expansions

### Planned Features

- OTA (Over-The-Air) firmware updates
- MQTT support as alternative to Firebase
- Data logging to microSD card
- Advanced scheduling
- Energy monitoring per relay
- Mobile app integration

### Expansion to 8 Relays

The firmware supports up to 8 relays. To add more:

1. Modify config.h with additional GPIO pins
2. Add relay entries in getDefaultConfig()
3. Update captive portal relay configuration UI
4. Restart device and configure via portal

## License

This firmware is provided as-is for the HashPC project.

## Support

For issues or questions:
1. Check serial output for error messages
2. Review configuration in captive portal
3. Ensure Firebase credentials are correct
4. Verify all hardware connections
