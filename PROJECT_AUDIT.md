# Project Audit - IoT PC Control System

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
