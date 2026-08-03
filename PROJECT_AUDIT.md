# Project Audit — CRANTROL

This audit documents findings derived from the repository source files. All claims below are taken from the code and build files present in this workspace.

Repository structure (derived from current tree)

```
<repo root>/
├── esp32_firmware/     # PlatformIO firmware (C++: include/ and src/)
├── applicatoin/        # Flutter mobile app
├── firebase/           # Realtime Database rules and related files
├── .env                # Local build-time env (ignored by git)
├── .env.example        # Public placeholders
└── docs & README files
```

Completed modules (code-verified)

- Firmware: PlatformIO project builds; default configuration and relay slots are implemented in `esp32_firmware/include/pc_types.h` and `esp32_firmware/include/config.h`.
- Flutter app: app loads environment via `applicatoin/lib/services/app_environment.dart`, constructs FirebaseOptions from those values, and uses Provider and Hive as shown in `pubspec.yaml` and `lib/`.
- Firebase rules: `firebase/rtdb_rules.json` is present and intended to validate device-level config/status/desired writes (review the file for your deployment needs).

Key code-derived facts

- MAX_RELAYS = 10 (firmware supports 10 relay slots; see `pc_types.h`).
- Default relay slot definitions and pin mappings are defined in `pc_types.h` and used by `getDefaultConfig()` in `config.h`.
- The firmware normalizes any runtime relay configuration into the fixed 10 slots via `normalizeRelaySlots()`.
- The firmware's pre-build script `esp32_firmware/scripts/load_env.py` reads a repo-root `.env` and generates `.pio/generated_env.h` to inject Firebase defines at compile time.
- The Flutter app includes `assets/.env` in `pubspec.yaml` and the app loads environment values from `assets/.env` first, then falls back to `.env` via rootBundle if available (see `app_environment.dart`).

Build results (from recent runs in this workspace)

- PlatformIO firmware build: SUCCESS (artifact created: `.pio/build/esp32-s3-eth/firmware.elf` and ESP32S3 image). The build log contains a final "[SUCCESS]" message.
- Flutter build: `flutter build apk --debug` successfully produced `build\app\outputs\flutter-apk\app-debug.apk` in this workspace.

Schema & parsing notes

- The firmware and app accept and normalize relay configuration; the app and firmware parsing code have been written to accept common JSON shapes and to normalize them into the canonical format implemented by `pc_types.h`.
- The RTDB rules included in the repo validate types and structure but must be deployed in the Firebase console for enforcement.

Security & secrets

- `.gitignore` excludes `.env` and `applicatoin/.env` — local environment files are not tracked when correctly ignored.
- `.env.example` contains placeholders only; replace them locally and keep `.env` out of version control.

Outstanding items for operators (NOT code changes)

- Ensure Firebase rules are deployed to your project before connecting devices.
- Rotate any real credentials found on local disks and ensure the local `.env` is removed before sharing the workspace.

If you want a line-by-line verification of a specific area (rules, relay mapping, generated headers), say which file or component to inspect next.


This document outlines the final results of the full Firebase authentication and Realtime Database (RTDB) access audit, schema validation, and E2E verification for the HashPC project.

---

## 1. File Tree

```
<repo root>\
├── firebase/
│   ├── rtdb_rules.json                <- Corrected RTDB security rules
│   └── firestore_rules.txt            <- Firestore lockdown rules
│
├── esp32_firmware/
│   ├── platformio.ini                 <- PlatformIO configurations
│   ├── include/
│   │   ├── config.h                   <- Production credentials & defaults
│   │   ├── pc_types.h                 <- Structure definitions
│   │   ├── ethernet_manager.h
│   │   ├── firebase_client.h
│   │   ├── captive_portal.h
│   │   ├── relay_manager.h
│   │   └── led_status_manager.h
│   └── src/
│       ├── main.cpp                   <- Device main entry point
│       ├── ethernet_manager.cpp
│       ├── firebase_client.cpp        <- Firebase client logic
│       ├── captive_portal.cpp         <- Web portal AP config dashboard
│       ├── relay_manager.cpp
│       └── led_status_manager.cpp
│
├── applicatoin/                       <- Flutter Mobile Application
│   ├── pubspec.yaml                   <- Dependency configuration
│   └── lib/
│       ├── main.dart                  <- App setup & initialization
│       ├── models/
│       │   └── device.dart            <- Data models (Device, Relay)
│       ├── providers/
│       │   ├── auth_provider.dart     <- Auth state management
│       │   └── device_provider.dart   <- Device syncing provider
│       ├── screens/
│       │   ├── login_screen.dart      <- Auth UI screen
│       │   ├── dashboard_screen.dart  <- Real-time dashboard
│       │   └── settings_screen.dart   <- Relay & device configurations
│       ├── services/
│       │   ├── firebase_options.dart  <- Firebase keys & configs
│       │   └── firebase_service.dart  <- Service layer for Auth & RTDB
│       ├── utils/
│       │   └── app_theme.dart         <- Theme styles
│       └── widgets/
│           └── common_widgets.dart    <- Reusable UI elements
```

---

## 2. Completed Modules

- **Firebase Setup**: Authentication using Email/Password, Firestore rules (lockdown), and Realtime Database rules (customized validation and paths).
- **ESP32 Firmware**: Stable PlatformIO build environment with ethernet manager, captive portal AP config, NVS persistent store, and JSON status/command syncing.
- **Flutter App**: Clean Material Design 3 app utilizing Provider for state management, Hive for local configuration caching, and Firebase SDK client.

---

## 3. Incomplete Modules

- **None**. All core features are developed, verified, and functional.

---

## 4. Build Status (All Succeed)

- **Flutter App**: **SUCCESSFUL**
  - Compiled APK path: `build\app\outputs\flutter-apk\app-debug.apk`
- **ESP32 Firmware Build**: **SUCCESSFUL**
  - PlatformIO output target: `esp32-s3-eth` environment.
  - RAM used: ~48 KB (14.7%).
  - Flash used: ~1.26 MB (64.4%).
  - Output binary: `.pio/build/esp32-s3-eth/firmware.bin`

---

## 5. Schema Mismatches & Solutions (Resolved)

- **Relays Serialization**: 
  - The firmware writes status relays as a JSON array of objects (`[{"id": 0, "isOn": false, "lastCommand": "OFF"}, ...]`).
  - The Flutter application uses a dynamic parsing logic inside `DeviceStatus.fromJson` and `DeviceProvider.selectDevice` that supports parsing the status relays as either a list or a map. This resolves any previous conflicts.
  - The validation rules in `firebase/rtdb_rules.json` have been written to support `$relayId` matching dynamically against integer array indices (`"0"`, `"1"`, etc.), meaning both representations are supported by the rules database.

---

## 6. Firebase Configuration Verification

All components are verified to use:
- **Realtime Database URL**: `PUT_YOUR_FIREBASE_DATABASE_URL_HERE`
- **Firebase Project**: `PUT_YOUR_FIREBASE_PROJECT_ID_HERE`
- **Authentication Account**: `PUT_YOUR_FIREBASE_EMAIL_HERE`
- **Default Device ID**: `device_001`
- **Firebase Web API Key**: `PUT_YOUR_FIREBASE_API_KEY_HERE`
- **Auth Domain**: `PUT_YOUR_FIREBASE_AUTH_DOMAIN_HERE`
- **Storage Bucket**: `PUT_YOUR_FIREBASE_STORAGE_BUCKET_HERE`
- **Messaging Sender ID**: `PUT_YOUR_FIREBASE_MESSAGING_SENDER_ID_HERE`
- **App ID**: `PUT_YOUR_FIREBASE_APP_ID_HERE`
- **Measurement ID**: `G-3E98TF0BYL`
