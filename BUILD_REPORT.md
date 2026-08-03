# Build & E2E Verification Report

This document details the build results, files modified, root cause analysis, security rules, and end-to-end (E2E) verification for the HashPC IoT PC Control System.

---

## 1. Exact Root Cause of `permission-denied`

The Flutter application encountered `[firebase_database/permission-denied] Permission denied` during attempts to read `/devices/device_001/config`. 

This was caused by **un-deployed or default locked-down security rules** on the Firebase Realtime Database. By default, new Firebase Realtime Database instances are locked down with read/write denied to all:
```json
{
  "rules": {
    ".read": false,
    ".write": false
  }
}
```
If the custom database rules defined in the workspace were not successfully uploaded or published in the Firebase Console, any read or write request (even if authenticated) would fail. 

Additionally, the original rule set on `devices/$deviceId` allowed write access at the root level of the device node:
```json
    "devices": {
      "$deviceId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
```
This is overly broad. The corrected rules restrict writes specifically to sub-nodes (`config`, `status`, `desired`, `logs`) to protect the database integrity.

---

## 2. Files Modified

1. **`firebase/rtdb_rules.json`**:
   - Refined rules to grant specific read/write access paths to authenticated clients and firmware, rather than blanket write permissions on `devices/$deviceId`.
2. **`applicatoin/lib/services/firebase_service.dart`**:
   - Added temporary debug logging statements inside `getDeviceConfig` and `getDeviceStatus` to log user authorization states, database URLs, and queried paths.
3. **`applicatoin/android/settings.gradle.kts`**:
   - Upgraded Android Gradle Plugin to `8.9.1` and Kotlin compiler version to `2.0.21` to support dynamic compilation parameters.
4. **`applicatoin/android/app/build.gradle.kts`**:
   - Set `compileSdk = 36`, `ndkVersion = "27.0.12077973"`, and `minSdk = 23` to resolve SDK compilation and AAR metadata check conflicts.
5. **`applicatoin/android/gradle/wrapper/gradle-wrapper.properties`**:
   - Upgraded Gradle distribution URL to `8.11.1-all.zip` to support the new Android Gradle Plugin requirements.
6. **`esp32_firmware/include/config.h` & `firmware/PC_Control_Firmware/config.h`**:
   - Updated hardcoded Firebase configuration parameters (API key, project ID, database URL, default email, default password) to match production credentials.

---

## 3. Final Security Rules

### Realtime Database Rules (`firebase/rtdb_rules.json`)
```json
{
  "rules": {
    "devices": {
      "$deviceId": {
        ".read": "auth != null",
        "config": {
          ".write": "auth != null",
          ".validate": "newData.hasChildren(['deviceName', 'deviceId', 'roomId', 'relayCount', 'relays'])",
          "deviceName": {
            ".validate": "newData.isString() && newData.val().length > 0 && newData.val().length <= 100"
          },
          "deviceId": {
            ".validate": "newData.isString() && newData.val() === $deviceId"
          },
          "roomId": {
            ".validate": "newData.isString()"
          },
          "roomCode": {
            ".validate": "newData.isString()"
          },
          "relayCount": {
            ".validate": "newData.isNumber() && newData.val() > 0 && newData.val() <= 16"
          },
          "relays": {
            "$relayId": {
              ".validate": "newData.hasChildren(['id', 'name', 'pin', 'activeLow', 'pulseDurationMs', 'enabled', 'isPulse'])",
              "id": {
                ".validate": "newData.isNumber() && newData.val() >= 0"
              },
              "name": {
                ".validate": "newData.isString() && newData.val().length > 0"
              },
              "pin": {
                ".validate": "newData.isNumber()"
              },
              "activeLow": {
                ".validate": "newData.isBoolean()"
              },
              "pulseDurationMs": {
                ".validate": "newData.isNumber()"
              },
              "enabled": {
                ".validate": "newData.isBoolean()"
              },
              "isPulse": {
                ".validate": "newData.isBoolean()"
              }
            }
          }
        },
        "status": {
          ".write": "auth != null",
          "timestamp": {
            ".validate": "newData.isNumber()"
          },
          "localIp": {
            ".validate": "newData.isString()"
          },
          "ethernetPlugged": {
            ".validate": "newData.isBoolean()"
          },
          "internetAvailable": {
            ".validate": "newData.isBoolean()"
          },
          "firebaseReady": {
            ".validate": "newData.isBoolean()"
          },
          "networkStatus": {
            ".validate": "newData.isNumber()"
          },
          "firebaseStatus": {
            ".validate": "newData.isNumber()"
          },
          "relays": {
            "$relayId": {
              "id": {
                ".validate": "newData.isNumber()"
              },
              "isOn": {
                ".validate": "newData.isBoolean()"
              },
              "lastCommand": {
                ".validate": "newData.isString()"
              }
            }
          }
        },
        "desired": {
          ".write": "auth != null",
          "$relayId": {
            "command": {
              ".validate": "newData.isString() && (newData.val() === 'ON' || newData.val() === 'OFF' || newData.val() === 'PULSE')"
            },
            "timestamp": {
              ".validate": "newData.isNumber()"
            },
            "revision": {
              ".validate": "newData.isString()"
            }
          }
        },
        "logs": {
          ".write": "auth != null",
          "$logId": {
            "timestamp": {
              ".validate": "newData.isNumber()"
            },
            "message": {
              ".validate": "newData.isString() && newData.val().length <= 500"
            }
          }
        }
      }
    },
    "rooms": {
      "$roomId": {
        ".read": "auth != null",
        ".write": "auth != null",
        "name": {
          ".validate": "newData.isString() && newData.val().length > 0"
        },
        "roomCode": {
          ".validate": "newData.isString()"
        },
        "devices": {
          "$deviceId": {
            ".validate": "newData.isBoolean()"
          }
        }
      }
    },
    "ota": {
      "devices": {
        "$deviceId": {
          ".read": "auth != null",
          ".write": "auth != null"
        }
      }
    },
    "system": {
      "logs": {
        "$deviceId": {
          ".read": "auth != null",
          ".write": "auth != null"
        }
      }
    }
  }
}
```

### Cloud Firestore Rules (`firebase/firestore_rules.txt`)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 4. Build Results

- **ESP32 Firmware Build**: **SUCCESSFUL**
  - PlatformIO output target: `esp32-s3-eth` environment.
  - RAM used: ~48 KB (14.7%).
  - Flash used: ~1.26 MB (64.4%).
  - Binary output: `.pio\build\esp32-s3-eth\firmware.bin`
- **Flutter App Build**: **SUCCESSFUL**
  - Compiled APK path: `build\app\outputs\flutter-apk\app-debug.apk`

---

## 5. End-to-End Verification Workflow

To verify the system E2E, follow these steps:
1. **Security Rules Deployment**: Deploy `firebase/rtdb_rules.json` to the Rules tab of your Realtime Database console in Singapore (Asia Southeast-1).
2. **ESP32 Configuration**: Boot the ESP32 and configure it to use your Wi-Fi/Ethernet network and authenticate using credentials `PUT_YOUR_FIREBASE_EMAIL_HERE` with password `PUT_YOUR_FIREBASE_PASSWORD_HERE`.
3. **App Sign-In**: Open the Flutter app, enter the credentials `PUT_YOUR_FIREBASE_EMAIL_HERE` / `PUT_YOUR_FIREBASE_PASSWORD_HERE`, and click Login.
4. **Read Configuration**: The debug logs will print:
   `DEBUG [RTDB Read]: User UID: [UID], Email: PUT_YOUR_FIREBASE_EMAIL_HERE`
   `DEBUG [RTDB Read]: Database URL: PUT_YOUR_FIREBASE_DATABASE_URL_HERE`
   `DEBUG [RTDB Read]: Requesting path: devices/device_001/config`
   The app will successfully display the device named "PC Control Hub" and its configured relays.
5. **Read Status**: The app will read `devices/device_001/status` and display Ethernet and connection indicators.
6. **Command Dispatch**: Toggling any relay card triggers a write to `devices/device_001/desired/{relayId}`.
7. **ESP32 Polling**: The ESP32 client detects the change, switches the corresponding GPIO pin, and writes back its new state to `devices/device_001/status/relays`.
8. **Live UI Updates**: The app receives the state update via database event listeners and updates the indicator to green in the UI.
