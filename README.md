# CRANTROL - Industrial Control Panel for ESP32-S3 Ethernet Systems

CRANTROL is an industrial-focused IoT control panel combining an ESP32-S3-ETH firmware, a Flutter mobile app, and a Firebase Realtime Database backend. This repository contains the firmware, mobile app, and Firebase rules needed to run and extend the system.

## Project overview

- Firmware: ESP32-S3 (PlatformIO / Arduino) controlling up to 10 relay channels, LED indicators, buzzer, and an optional W5500 Ethernet module.
- Mobile app: Flutter application (applicatoin/) for authentication, device control, relay sequencing, and configuration.
- Cloud: Firebase Realtime Database for device state, desired commands, and simple authentication (email/password).

Everything in these docs is derived from the current codebase. Do not rely on external or historical documentation for runtime behavior.

## High-level architecture

```
Flutter mobile app  ⇄  Firebase Realtime Database  ⇄  ESP32-S3-ETH Firmware
```

- Mobile App: authenticates users, shows device dashboard, controls relays, and saves configuration.
- Firebase RTDB: stores device configuration (devices/{deviceId}/config), current status (devices/{deviceId}/status), desired commands (devices/{deviceId}/desired) and logs.
- ESP32 Firmware: reads configuration, exposes captive portal for initial setup, connects via Ethernet (preferred) or Wi‑Fi for setup, and executes relay commands.

## Repository layout

```
<repo root>/
├── esp32_firmware/        # PlatformIO / Arduino firmware (C++ source)
│   ├── include/           # headers (pc_types.h, config.h, ...)
│   ├── src/               # implementation
│   ├── scripts/           # pre-build helpers (load_env.py)
│   └── platformio.ini     # build configuration
├── applicatoin/           # Flutter mobile application
│   ├── lib/               # Dart source
│   ├── assets/            # packaged assets (assets/.env)
│   └── pubspec.yaml
├── firebase/              # Realtime Database rules and related files
├── .env                   # repo-level placeholders used by firmware build script (ignored by git)
├── .env.example           # example env for contributors
└── README.md              # this file
```

Notes:
- The repository-level `.env` is used by the firmware build pre-script (esp32_firmware/scripts/load_env.py) to populate generated_env.h.
- The Flutter app reads environment values from `assets/.env` (see applicatoin/lib/services/app_environment.dart). `assets/.env` is included in `pubspec.yaml`.

## Relay architecture and defaults (source of truth)

The firmware supports exactly 10 relay slots (MAX_RELAYS = 10). Default relay IDs, names, pins and pulse settings are defined in `esp32_firmware/include/pc_types.h` and wired into `getDefaultConfig()` in `esp32_firmware/include/config.h`.

Default relay slots (ID → name / pin / notes):

- Relay 1 — "PC Power"        — GPIO 21 (default pulseMs: 350ms)
- Relay 2 — "Monitor 1"       — GPIO 17
- Relay 3 — "Monitor 2"       — GPIO 16
- Relay 4 — "Motherboard Power Button" — GPIO 18 (pulseMs: 250ms)
- Relay 5 — "Relay 5"         — GPIO 15
- Relay 6 — "Relay 6"         — GPIO 3
- Relay 7 — "Relay 7"         — GPIO 2
- Relay 8 — "Relay 8"         — GPIO 1
- Relay 9 — "Power"           — GPIO 0 (pulse relay, pulseMs: 4000ms)
- Relay 10 — "Reset"          — GPIO 44 (pulse relay, pulseMs: 1000ms)

- Default relayCount is 10 and the firmware normalizes any provided configuration into these 10 slots.
- `isPulse` is true by default for relays 9 and 10 (momentary/pulse behavior).
- `activeLow` default is true in code; relay-level `activeLow` can be overridden per-slot in device configuration.

Hardware pin constants are defined in `esp32_firmware/include/config.h`:

- RELAY_1_PIN .. RELAY_10_PIN (21,17,16,18,15,3,2,1,0,44)
- BUZZER_PIN = 43
- STATUS_LED_PIN = 47
- NETWORK_LED_PIN = 48
- RGB_LED_PIN = 46

Ethernet (W5500 SPI) pins in config.h:
- MISO = 12, MOSI = 11, SCLK = 13, CS = 14, IRQ = 10, RST = 9

Default captive-portal AP settings (from config.h):
- SSID: "PC-Control-Setup"
- Password: "12345678"

## Environment files & secrets (public-repo safety)

- `.env.example` (root): provided with placeholder values and safe to publish.
- `.env` (root): used by `esp32_firmware/scripts/load_env.py` at build time. It should contain Firebase keys in local developer environments but must be kept out of source control.
- `applicatoin/assets/.env`: packaged into the Flutter app (listed in `pubspec.yaml`). Use this to bundle non-sensitive defaults or CI-injected values; do not store production secrets in the repository.

Git hygiene in this repo already ignores `.env` and development-only environment files. Before publishing or sharing, rotate any real credentials and ensure nothing sensitive is tracked.

## Firebase structure (high level)

The firmware and app use the following Realtime Database layout (keys derived from code behaviour):

```
devices/
  {deviceId}/
    config/    ← persisted device configuration (relay mapping, names, network)
    status/    ← real-time device status (ethernet, firebaseReady, relay states)
    desired/   ← transient desired relay commands written by clients
    logs/      ← optional event logs
```

- Clients write commands to `devices/{deviceId}/desired/{relayId}` (with `command`, `timestamp`, `revision`).
- The device processes `desired` entries, executes relays, and writes back into `status`.

## Verified build steps (from this workspace)

Flutter (applicatoin/):

```bash
cd applicatoin
flutter pub get
flutter pub run build_runner build   # generates Hive adapters
flutter analyze                      # static analysis (warnings/info)
flutter test                         # unit/widget tests
flutter build apk --debug            # produces debug APK
```

ESP32 Firmware (esp32_firmware/):

```bash
cd esp32_firmware
# PlatformIO builds using the esp32-s3-eth environment
platformio run -e esp32-s3-eth
# To upload (device attached):
platformio run -e esp32-s3-eth --target upload
```

Notes:
- `esp32_firmware/scripts/load_env.py` reads the repo root `.env` and generates `.pio/generated_env.h` at build time to inject Firebase values into firmware builds.
- The `platformio.ini` in this repo is configured to use the `esp32-s3-eth` environment.

## Troubleshooting (accurate to current implementation)

- Firmware link/build problems: clean `esp32_firmware/.pio` and rebuild. If PlatformIO packages are corrupted, re-install PlatformIO packages or remove problematic cached packages.
- Missing Firebase values in firmware runtime: ensure `.env` (repo root) contains FIREBASE_* keys before platformio builds, or the firmware defaults to placeholder values defined in `config.h`.
- Flutter: if `assets/.env` is missing, the app falls back to placeholder values. Ensure `assets/.env` is present when building a packaged app.
- Relay not responding: check wiring and the per-relay `pin` mapping in device `config` stored under `devices/{deviceId}/config/relays` in RTDB.

## Where to look in the code (quick links)

- esp32_firmware/include/pc_types.h — relay slots and defaults (source of relay names/pins)
- esp32_firmware/include/config.h — pin constants, AP defaults, and getDefaultConfig()
- esp32_firmware/scripts/load_env.py — firmware env → generated header
- applicatoin/lib/services/app_environment.dart — Flutter env loader (reads assets/.env then .env)
- applicatoin/lib/services/firebase_options.dart — Firebase options built from AppEnvironment

## Contributing & publishing

- Keep `.env` out of version control. Use `.env.example` for contributors.
- Rotate Firebase credentials if they were ever leaked.
- Update `firebase/rtdb_rules.json` in the repo and deploy rules from the Firebase Console.

---

For more developer-focused details and step-by-step deployment, see `IMPLEMENTATION_GUIDE.md`, `DEPLOYMENT_CHECKLIST.md`, and `esp32_firmware/README.md`.
