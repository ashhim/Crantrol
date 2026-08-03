
# CRANTROL — Firmware Overview

This firmware README summarizes the firmware behavior implemented in `esp32_firmware/`. The text below is based on the current source files in that folder and is accurate to the code in this workspace.

Purpose

The firmware runs on ESP32-S3 hardware with an optional W5500 Ethernet module. It:

- Connects to Firebase Realtime Database to receive relay commands and report status.
- Exposes a captive portal for initial setup and configuration (AP + web UI).
- Controls a fixed set of relay slots (default: 10) with support for latched and pulse relays.
- Drives LED indicators and a buzzer for status feedback.
- Persists configuration in NVS.

Primary data model and DB layout

- `devices/{deviceId}/config` — device configuration, relay mapping
- `devices/{deviceId}/status` — current status (ethernet, firebase, relays)
- `devices/{deviceId}/desired` — commands written by clients
- `devices/{deviceId}/logs` — optional runtime logs

Relay defaults and configuration

- Default relay slots are defined in `esp32_firmware/include/pc_types.h` and normalized into a 10-slot layout.
- Each slot contains: id, name, pin, activeLow, pulseMs/pulseDurationMs, enabled, isPulse.
- The firmware's `normalizeRelaySlots()` and `getDefaultConfig()` implement how runtime config maps into slots.

Captive portal & configuration

- The captive portal is provided for initial configuration and reconfiguration of device settings. Defaults (from `config.h`):
  - AP SSID: `PC-Control-Setup`
  - AP password: `12345678`
  - Portal IP: `http://192.168.4.1`
- Portal actions are persisted into NVS so devices will boot configured after setup.

Build-time environment injection

- `esp32_firmware/scripts/load_env.py` reads repo-root `.env` and writes `.pio/generated_env.h` with FB_* `#define`s consumed at compile time.
- If no `.env` is present, firmware will compile with default placeholder values defined in `config.h`.

Where to find defaults in code

- Relay defaults: `esp32_firmware/include/pc_types.h`
- Pin constants & AP defaults: `esp32_firmware/include/config.h`
- Generated env script: `esp32_firmware/scripts/load_env.py`

Operation & diagnostics

- Serial output at 115200 includes tags such as `[ETH]`, `[FB]`, and `[RELAY]` for diagnosing behavior.
- LED status semantics are implemented in `led_status_manager.cpp` and wired to pins in `config.h`.

Security considerations

- Do not commit real Firebase credentials into the repository. Use `.env.example` for placeholders.
- Deploy `firebase/rtdb_rules.json` to the production Firebase project prior to allowing device connections.

This file intentionally documents only behaviors implemented in the code. For implementation details, review the source headers and implementation files referenced above.


Waveshare ESP32-S3-ETH firmware for:
- Ethernet (W5500)
- Firebase email/password authentication
- Firebase Realtime Database control
- Captive portal configuration
- Relay control with expandable relay mapping
- WS2812 RGB status indication

## Default Firebase schema

`devices/<deviceId>/desired`
```json
{
  "revision": 1,
  "relays": {
    "r1": true,
    "r2": false,
    "r3": true,
    "r4": false
  },
  "frontPanelPulseMs": 250
}
```

`devices/<deviceId>/status`
```json
{
  "deviceId": "pc-XXXXXX",
  "deviceName": "PC Control Hub",
  "ethernetLinked": true,
  "ethernetGotIp": true,
  "internetOk": true,
  "firebaseAuthenticated": true,
  "ip": "192.168.1.50",
  "configRevision": 1,
  "relays": [
    { "index": 1, "name": "PC Power", "state": false }
  ]
}
```

## Captive portal
- Connect to the AP shown in the firmware settings
- Open the portal IP (usually `192.168.4.1`)
- Log in using your Firebase email/password
- Change relay names, pins, active-low mode, pulse timing, and LED pins
- Save to NVS and reboot

## Important board note
The Waveshare ESP32-S3-ETH wiki states GPIO33~GPIO37 are internally occupied and unavailable on the board. The firmware keeps your requested relay defaults for compatibility, but if a relay does not respond, remap the pin in the captive portal to a free GPIO. The board also uses GPIO21 for the onboard WS2812 RGB LED, and its Ethernet demo documents the W5500 SPI pins used in this project. 

## Library requirements
Install these in Arduino IDE:
- Adafruit NeoPixel
- ArduinoJson
- ESP32 board package


Note: pc_types.h is included to satisfy Arduino IDE prototype generation.
