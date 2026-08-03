# HashPC - Complete IoT PC Control System

A production-ready IoT system for remote PC control combining an ESP32-S3-ETH firmware, Flutter mobile app, and Firebase cloud backend.

## 📋 Project Overview

HashPC allows you to:
- Control PC power, monitors, and other devices via relays
- Manage devices remotely through Firebase Realtime Database
- Configure devices via a captive Wi-Fi portal
- Monitor device status in real-time through a beautiful Flutter app
- Expand from 4 relays to 8 relays without redesign

## 🏗️ System Architecture

```
┌─────────────────────┐
│   Flutter Mobile App │ ◄──► Firebase Authentication
└─────────────────────┘      Firebase Realtime Database
          △
          │ HTTPS REST/gRPC
          │
┌─────────────────────────┐
│  Google Firebase Cloud  │
├─────────────────────────┤
│ • Authentication        │
│ • Realtime Database     │
│ • Rules & Security      │
└─────────────────────────┘
          △
          │ HTTPS REST
          │
┌─────────────────────────────────────────┐
│  ESP32-S3-ETH Firmware                  │
├─────────────────────────────────────────┤
│ • Ethernet (W5500)                      │
│ • Relay Control (GPIO)                  │
│ • Captive Portal (WiFi AP)              │
│ • RGB LED Status Indication             │
│ • NVS Configuration Storage             │
└─────────────────────────────────────────┘
          │
          └──► 4-8 Relays (Power Control)
```

## 📦 Project Structure

```
hashpc/
├── esp32_firmware/                  # ESP32 firmware (Arduino)
│   ├── esp32_firmware.ino          # Main sketch
│   ├── include/
│   │   ├── pc_types.h              # Type definitions
│   │   ├── config.h                # Configuration
│   │   ├── relay_manager.h         # Relay control
│   │   ├── led_status_manager.h    # LED status
│   │   ├── ethernet_manager.h      # Network
│   │   ├── firebase_client.h       # Firebase
│   │   └── captive_portal.h        # Web UI
│   ├── src/                         # Implementation files
│   ├── platformio.ini              # Build config
│   └── README.md                   # Firmware guide
│
├── applicatoin/                     # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart               # App entry
│   │   ├── models/                 # Data models
│   │   ├── services/               # Firebase service
│   │   ├── providers/              # State management
│   │   ├── screens/                # UI screens
│   │   ├── widgets/                # Reusable widgets
│   │   └── utils/                  # Themes & helpers
│   ├── pubspec.yaml                # Dependencies
│   └── README.md                   # App guide
│
├── firebase/                        # Cloud rules
│   ├── rtdb_rules.json             # RTDB security rules
│   └── firestore_rules.txt         # Firestore rules
│
└── README.md                        # This file
```

## 🚀 Quick Start

### 1. ESP32 Firmware Setup

```bash
cd esp32_firmware

# Option A: Arduino IDE
# 1. Open esp32_firmware.ino in Arduino IDE
# 2. Install dependencies (ArduinoJson, Adafruit NeoPixel)
# 3. Select board: ESP32S3 Dev Module
# 4. Upload

# Option B: PlatformIO
platformio run -e esp32-s3-eth --target upload
```

### 2. Flutter App Setup

```bash
cd applicatoin

# Install dependencies
flutter pub get

# Generate model adapters (Hive)
flutter pub run build_runner build

# Run app
flutter run
```

### 3. Firebase Configuration

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project "CRANTROL"
3. Enable Authentication (Email/Password)
4. Create Realtime Database
5. Copy rules from `firebase/rtdb_rules.json` to Database Rules
6. Add default credentials:
   - Email: `PUT_YOUR_FIREBASE_EMAIL_HERE`
   - Password: `PUT_YOUR_FIREBASE_PASSWORD_HERE`

## 🔐 Security & Credentials

### Firebase Credentials
```
API Key: PUT_YOUR_FIREBASE_API_KEY_HERE
Auth Domain: PUT_YOUR_FIREBASE_AUTH_DOMAIN_HERE
Database URL: PUT_YOUR_FIREBASE_DATABASE_URL_HERE
Project ID: PUT_YOUR_FIREBASE_PROJECT_ID_HERE
Storage Bucket: PUT_YOUR_FIREBASE_STORAGE_BUCKET_HERE
Messaging Sender ID: PUT_YOUR_FIREBASE_MESSAGING_SENDER_ID_HERE
App ID: PUT_YOUR_FIREBASE_APP_ID_HERE

Default Admin Account:
Email: PUT_YOUR_FIREBASE_EMAIL_HERE
Password: PUT_YOUR_FIREBASE_PASSWORD_HERE
```

**⚠️ IMPORTANT**: In production:
- Change default password immediately
- Enable Multi-Factor Authentication
- Use environment variables for credentials
- Implement role-based access control
- Enable Firebase Security Rules (included)

## 💾 Hardware Configuration

### GPIO Pin Mapping

| Device | Pin | Purpose |
|--------|-----|---------|
| Relay 1 | GPIO33 | PC Power ON/OFF |
| Relay 2 | GPIO34 | Monitor 1 Power |
| Relay 3 | GPIO35 | Monitor 2 Power |
| Relay 4 | GPIO36 | PC Power Button (Pulse) |
| Status LED | GPIO47 | Status Indicator |
| Network LED | GPIO48 | Network Status |
| RGB LED | GPIO21 | Multicolor Status (onboard) |
| Buzzer | GPIO46 | Audio Feedback |

### Ethernet W5500 SPI

| Signal | Pin |
|--------|-----|
| MISO | GPIO12 |
| MOSI | GPIO11 |
| SCLK | GPIO13 |
| CS | GPIO14 |
| IRQ | GPIO10 |
| RST | GPIO9 |

## 🌐 Network & Firebase

### RGB LED Status Codes

| Color | Status |
|-------|--------|
| 🔵 Blue | Ethernet not connected |
| 🟠 Orange | Ethernet connected, no internet |
| 🟢 Green (blinking) | Internet ready & Firebase connected |
| 🔴 Red (blinking) | Internet down |

### Firebase Database Structure

```
devices/
  {deviceId}/
    config/
      deviceName: "HashPC-Device-001"
      deviceId: "device_001"
      roomId: "room_001"
      relays: [...]
      allowedUsers: {uid: true, ...}
    
    status/
      timestamp: 1234567890
      ethernetPlugged: true
      internetAvailable: true
      firebaseReady: true
      relays:
        1: {id: 1, isOn: false, lastCommand: "OFF"}
        2: {id: 2, isOn: true, lastCommand: "ON"}
      
    desired/
      1: {command: "ON", timestamp: ..., revision: "..."}
      
    logs/
      log1: {timestamp: ..., message: "...", level: "INFO"}
```

## 📱 Flutter App Features

### Screens

1. **Login Screen**
   - Email/Password authentication
   - Error handling
   - Persistent login session

2. **Dashboard**
   - Device status display
   - Network connectivity indicators
   - Real-time relay state
   - Toggle/Pulse controls

3. **Settings**
   - Device configuration
   - Relay mapping
   - Relay naming
   - Save to Firebase

4. **Logs** (Future)
   - Device event history
   - Error tracking

### Navigation

```
Login → Dashboard ─┬─→ Settings
                   └─→ Relay Control
```

## ⚙️ Relay Configuration

### Relay Types

**Latched Relay** (Default for 1-3)
- ON/OFF states are maintained
- Power must be cut to change state
- Used for power control

**Pulse Relay** (Default for 4)
- Momentary pulse activation
- Automatically returns to OFF
- Used for button simulation

### Example Configuration

```json
{
  "id": 4,
  "name": "PC Power Button",
  "pin": 36,
  "activeLow": false,
  "isPulse": true,
  "pulseDurationMs": 500,
  "enabled": true
}
```

## 🔧 Configuration & Persistence

### Captive Portal Setup

1. Device starts with default config
2. Broadcasts Wi-Fi AP: "HashPC-Setup"
3. Connect and open http://192.168.4.1
4. Login with Firebase credentials
5. Configure all settings
6. Save (stored in NVS)

### NVS Storage

- Device name
- Firebase credentials
- Relay GPIO mapping
- LED pin assignments
- AP name/password
- Room configuration

Persists across reboots.

## 📊 Data Flow

### Relay Command Execution

```
1. User taps "ON" in Flutter app
   ↓
2. App writes to Firebase: devices/{deviceId}/desired/1 = {command: "ON", ...}
   ↓
3. ESP32 polls Firebase every 5 seconds
   ↓
4. ESP32 detects new command
   ↓
5. ESP32 executes relay: GPIO33 → HIGH
   ↓
6. ESP32 writes status: devices/{deviceId}/status/relays/1 = {isOn: true, ...}
   ↓
7. Flutter app receives update via listener
   ↓
8. UI updates automatically
```

## 🛡️ Security Rules

### Firebase Realtime Database

- Default deny-all policy
- Only authenticated users can access
- Users can only access their own devices
- Device status is read-only for other users
- Commands are write-restricted
- All data validates against schema

See `firebase/rtdb_rules.json` for complete rules.

## 📡 Expansion to 8 Relays

### Current: 4 Relays

```
Relay 1 (GPIO33) ─ PC Power
Relay 2 (GPIO34) ─ Monitor 1
Relay 3 (GPIO35) ─ Monitor 2
Relay 4 (GPIO36) ─ PC Button
```

### Future: 8 Relays

```
Relay 1 (GPIO33) ─ PC Power
Relay 2 (GPIO34) ─ Monitor 1
Relay 3 (GPIO35) ─ Monitor 2
Relay 4 (GPIO36) ─ PC Button
Relay 5 (GPIO37) ─ Desk Lamp
Relay 6 (GPIO38) ─ Fan
Relay 7 (GPIO39) ─ Speaker
Relay 8 (GPIO40) ─ Humidifier
```

To expand:
1. Update `config.h` with new GPIO pins
2. Modify `getDefaultConfig()` in config.h
3. Access captive portal and reconfigure
4. Firmware auto-detects relay count

## 🐛 Troubleshooting

### ESP32 Issues

**Ethernet not detected**
- Check cable connection
- Verify GPIO pins match hardware
- Check serial output for "[ETH]" messages

**Firebase auth fails**
- Verify credentials in captive portal
- Check internet connectivity
- Look for "[FB]" error messages

**Relays not responding**
- Verify GPIO mapping
- Check relay module wiring
- Test "activeLow" setting
- Monitor serial for relay commands

### Flutter Issues

**Login fails**
- Check Firebase credentials
- Verify Firebase Authentication is enabled
- Check internet connectivity
- Review Firebase rules

**Device shows offline**
- Ensure ESP32 has internet (via Ethernet)
- Verify Firebase connection
- Check Firebase Realtime Database access
- Review RTDB rules

**No relay updates**
- Check real-time listener setup
- Verify Firebase database permissions
- Check command format
- Review device logs

## 📚 Documentation Files

- `esp32_firmware/README.md` - Detailed firmware guide
- `applicatoin/README.md` - Flutter app development guide
- `firebase/SECURITY.md` - Security best practices

## 🔄 Workflow Examples

### Turning on PC Power

```
App (User) ──→ Flutter App ──→ Firebase RTDB ──→ ESP32
                                      ↓
                                 desired/{1}
                                      ↑
                           ← status/{relays/1}
                           ← LED: Green (connected)
           ← Real-time update
```

### Emergency Power Button

```
Captive Portal ──→ GPIO36 ──→ 500ms pulse ──→ PC Front Panel
```

## 🚀 Deployment Checklist

- [ ] Update Firebase credentials in config.h
- [ ] Change default admin password
- [ ] Enable Firebase Security Rules
- [ ] Test all 4 relays
- [ ] Test Ethernet failover
- [ ] Configure captive portal SSID
- [ ] Test Flutter app login
- [ ] Verify real-time updates work
- [ ] Test relay commands from app
- [ ] Verify LED status indicators
- [ ] Test device restart
- [ ] Document relay GPIO mapping
- [ ] Create backup of configuration

## 📝 License

This project is provided as-is for the HashPC initiative.

## 🤝 Support & Contact

For issues or questions:
1. Check device serial output (115200 baud)
2. Review Firebase console for errors
3. Verify network connectivity
4. Check RTDB rules are deployed

## 🎯 Future Enhancements

- OTA firmware updates
- MQTT support
- Data logging to cloud storage
- Advanced scheduling
- Energy monitoring
- Web dashboard
- Mobile notifications
- Voice control integration
- Scene/macro support
- Backup & restore configuration
