# CRANTROL — Quick Reference

This quick reference summarizes the current CRANTROL codebase and runtime behavior. All information below is taken from the repository source (firmware headers and app code).

## At a glance

- Project: CRANTROL (Flutter app + ESP32-S3-ETH firmware + Firebase RTDB)
- Relay slots supported by firmware: 10 (MAX_RELAYS = 10)
- Firmware build: PlatformIO (environment `esp32-s3-eth`)
- App build: Flutter (assets/.env is the packaged environment file)

## Repo locations

```
<repo root>/
├── esp32_firmware/   # Firmware (PlatformIO / Arduino)
├── applicatoin/      # Flutter mobile app
├── firebase/         # RTDB rules and related files
├── .env              # Build-time env used by firmware scripts (local only)
└── .env.example      # Public example (placeholders)
```

## Default captive portal (from firmware config.h)

- AP SSID: `PC-Control-Setup`
- AP Password: `12345678`
- Portal URL: http://192.168.4.1

> Note: AP defaults come from `esp32_firmware/include/config.h`.

## Relay defaults and pin mapping (source of truth)

| Relay ID | Default name                     | GPIO pin | Notes |
|----------|----------------------------------|----------|-------|
| 1        | PC Power                         | 21       | default pulseMs = 350ms |
| 2        | Monitor 1                        | 17       |       |
| 3        | Monitor 2                        | 16       |       |
| 4        | Motherboard Power Button         | 18       | pulseMs = 250ms |
| 5        | Relay 5                          | 15       |       |
| 6        | Relay 6                          | 3        |       |
| 7        | Relay 7                          | 2        |       |
| 8        | Relay 8                          | 1        |       |
| 9        | Power                            | 0        | pulse relay, pulseMs = 4000ms |
| 10       | Reset                            | 44       | pulse relay, pulseMs = 1000ms |

- Default `activeLow` is true in code; individual slot `activeLow` can be overridden at runtime via device config.
- The firmware normalizes any user-supplied relay configuration into these 10 slots (see `pc_types.h`).

## Useful pin constants (config.h)

- BUZZER_PIN = 43
- STATUS_LED_PIN = 47
- NETWORK_LED_PIN = 48
- RGB_LED_PIN = 46
- Ethernet (W5500) SPI: MISO=12, MOSI=11, SCLK=13, CS=14, IRQ=10, RST=9

## Environment files & where they are used

- `esp32_firmware/scripts/load_env.py` reads repo-root `.env` to generate `.pio/generated_env.h` before building firmware.
- Flutter app: `applicatoin/lib/services/app_environment.dart` attempts to load `assets/.env` (packaged) then falls back to `.env` via rootBundle; the app includes `assets/.env` in `pubspec.yaml`.
- `.env.example` is the public template; replace placeholders with your own values for local development — never commit secrets.

## Quick commands

Firmware (PlatformIO):

```bash
cd esp32_firmware
platformio run -e esp32-s3-eth          # build
platformio run -e esp32-s3-eth --target upload  # upload
```

Flutter (applicatoin):

```bash
cd applicatoin
flutter pub get
flutter pub run build_runner build
flutter run
flutter build apk --debug
```

## Firebase / RTDB layout (runtime)

```
devices/{deviceId}/
  config/   ← persisted configuration (relays array)
  status/   ← device-reported state, relays
  desired/  ← commands written by clients
  logs/     ← optional event logs
```

## Quick troubleshooting

- Build errors: clean `.pio` and rebuild. Confirm PlatformIO packages are not corrupted.
- Missing Firebase in firmware: ensure repo `.env` contains FIREBASE_* before firmware build.
- App shows placeholders: ensure `applicatoin/assets/.env` is present and contains expected keys, or set env via CI.

## Where to inspect code

- Relay defaults: `esp32_firmware/include/pc_types.h`
- Pin constants and defaults: `esp32_firmware/include/config.h`
- Firmware env → C defines: `esp32_firmware/scripts/load_env.py`
- Flutter env parsing: `applicatoin/lib/services/app_environment.dart`

---

This quick reference is intentionally concise — for full instructions and deployment steps, consult `IMPLEMENTATION_GUIDE.md`, `DEPLOYMENT_CHECKLIST.md`, and the firmware/app README files.
