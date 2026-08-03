
# PC Control Firmware

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
