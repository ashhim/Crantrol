#ifndef PC_TYPES_H
#define PC_TYPES_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include <vector>

static constexpr uint8_t MAX_RELAYS = 10;

enum class NetworkStatus {
  NOT_PLUGGED = 0,
  PLUGGED_NO_IP = 1,
  IP_ACQUIRED = 2,
  INTERNET_READY = 3,
  INTERNET_DOWN = 4
};

enum class FirebaseStatus {
  DISCONNECTED = 0,
  AUTHENTICATING = 1,
  AUTHENTICATED = 2,
  AUTH_FAILED = 3
};

struct RelayConfig {
  uint8_t id = 0;
  String name;
  int pin = -1;
  bool activeLow = true;
  uint16_t pulseMs = 0;         // 0 = latched, >0 = momentary pulse
  uint16_t pulseDurationMs = 0;  // Alias for pulseMs used in some UI components
  bool enabled = true;
  bool isPulse = false;
  bool state = false;            // Current relay state (ON/OFF)
};

struct FirebaseConfig {
  String apiKey;
  String authDomain;
  String databaseURL;
  String projectId;
  String storageBucket;
  String messagingSenderId;
  String appId;
  String email;
  String password;
};

struct NetworkConfig {
  String deviceName;
  String deviceId;
  String roomId;
  String roomCode;
  String apName;
  String apPassword;
  bool externalLedEnabled;
  uint8_t rgbLedPin;
  uint8_t statusLedPin;
  uint8_t networkLedPin;
  uint8_t buzzerPin;
};

struct AppConfig {
  NetworkConfig network;
  FirebaseConfig firebase;
  uint8_t relayCount = 10;
  std::vector<RelayConfig> relays;
  uint32_t statusPushIntervalMs = 5000;
  uint32_t desiredPollIntervalMs = 2000;
  uint32_t configRevision = 1;
  uint32_t lastSavedTime = 0;

  // Offline-first captive portal sync: true whenever the locally-saved (NVS)
  // configuration has not yet been confirmed pushed to Firebase. Starts true
  // so a freshly booted device always re-syncs once connectivity returns.
  bool configPendingSync = true;
};

struct RelayState {
  uint8_t relayId;
  bool isOn;
  uint32_t lastCommandTime;
  String lastCommand;
  String commandRevision;
};

struct RuntimeState {
  NetworkStatus netStatus;
  FirebaseStatus fbStatus;
  bool isEthernetPlugged;
  bool internetAvailable;
  bool firebaseReady;
  uint32_t lastNetworkCheck;
  uint32_t lastFirebaseCheck;
  String localIp;
  String macAddress;
  std::vector<RelayState> relayStates;
  
  // Heartbeat/online state diagnostics
  bool ethernetLinked = false;
  bool ethernetGotIp = false;
  bool internetOk = false;
  bool firebaseAuthenticated = false;
  uint64_t lastSeenAt = 0;
  uint64_t heartbeatAt = 0;
  uint32_t uptimeMs = 0;

  // Authoritative PC power state from the motherboard PLED sense input
  // (GPIO45) — debounced. This is NOT derived from Relay 1.
  bool pcActualOn = false;
  bool pcActualStable = false;
};

struct FirebaseCommand {
  String relayId;
  String command;
  uint64_t timestamp;
  String revision;
};

inline RelayConfig makeRelaySlot(uint8_t id) {
  RelayConfig relay;
  relay.id = id;
  relay.name = "Relay " + String(id);
  relay.pin = 0;
  relay.activeLow = true;
  relay.pulseMs = 0;
  relay.pulseDurationMs = 0;
  relay.enabled = false;
  relay.isPulse = false;
  relay.state = false;

  switch (id) {
    case 1:
      relay.name = "PC Power";
      relay.pin = 21;
      relay.pulseMs = 350;
      relay.pulseDurationMs = 350;
      relay.enabled = true;
      break;
    case 2:
      relay.name = "Monitor 1";
      relay.pin = 17;
      relay.enabled = true;
      break;
    case 3:
      relay.name = "Monitor 2";
      relay.pin = 16;
      relay.enabled = true;
      break;
    case 4:
      relay.name = "Motherboard Power Button";
      relay.pin = 18;
      relay.pulseMs = 250;
      relay.pulseDurationMs = 250;
      relay.enabled = true;
      break;
    case 5:
      relay.name = "Relay 5";
      relay.pin = 15;
      relay.enabled = true;
      break;
    case 6:
      relay.name = "Relay 6";
      relay.pin = 3;
      relay.enabled = true;
      break;
    case 7:
      relay.name = "Relay 7";
      relay.pin = 2;
      relay.enabled = true;
      break;
    case 8:
      relay.name = "Relay 8";
      relay.pin = 1;
      relay.enabled = true;
      break;
    case 9:
      relay.name = "Power";
      relay.pin = 0;
      relay.pulseMs = 4000;
      relay.pulseDurationMs = 4000;
      relay.enabled = true;
      relay.isPulse = true;
      break;
    case 10:
      relay.name = "Reset";
      relay.pin = 44;
      relay.pulseMs = 1000;
      relay.pulseDurationMs = 1000;
      relay.enabled = true;
      relay.isPulse = true;
      break;
    default:
      break;
  }

  return relay;
}

inline std::vector<RelayConfig> makeDefaultRelaySlots() {
  std::vector<RelayConfig> relays;
  relays.reserve(MAX_RELAYS);
  for (uint8_t id = 1; id <= MAX_RELAYS; ++id) {
    relays.push_back(makeRelaySlot(id));
  }
  return relays;
}

inline RelayConfig readRelaySchema(JsonObjectConst relayObj, const RelayConfig& fallback) {
  RelayConfig relay = fallback;

  if (relayObj.containsKey("id")) {
    relay.id = relayObj["id"] | fallback.id;
  }

  if (relayObj.containsKey("name")) {
    String name = relayObj["name"].as<String>();
    name.trim();
    if (!name.isEmpty()) {
      relay.name = name;
    }
  }

  if (relayObj.containsKey("pin")) {
    relay.pin = relayObj["pin"] | fallback.pin;
  }

  if (relayObj.containsKey("activeLow")) {
    relay.activeLow = relayObj["activeLow"] | fallback.activeLow;
  }

  if (relayObj.containsKey("pulseMs")) {
    relay.pulseMs = relayObj["pulseMs"] | fallback.pulseMs;
  }

  if (relayObj.containsKey("pulseDurationMs")) {
    relay.pulseDurationMs = relayObj["pulseDurationMs"] | fallback.pulseDurationMs;
  }

  if (relayObj.containsKey("enabled")) {
    relay.enabled = relayObj["enabled"] | fallback.enabled;
  }

  if (relayObj.containsKey("isPulse")) {
    relay.isPulse = relayObj["isPulse"] | fallback.isPulse;
  }

  if (relayObj.containsKey("state")) {
    relay.state = relayObj["state"] | fallback.state;
  }

  if (relay.pulseDurationMs == 0) {
    relay.pulseDurationMs = relay.pulseMs;
  }
  if (relay.pulseMs == 0 && relay.pulseDurationMs > 0) {
    relay.pulseMs = relay.pulseDurationMs;
  }

  return relay;
}

inline void writeRelaySchema(JsonObject relayObj, const RelayConfig& relay) {
  relayObj["id"] = relay.id;
  relayObj["name"] = relay.name.c_str();
  relayObj["pin"] = relay.pin;
  relayObj["activeLow"] = relay.activeLow;
  relayObj["pulseMs"] = relay.pulseMs;
  relayObj["pulseDurationMs"] = relay.pulseDurationMs;
  relayObj["enabled"] = relay.enabled;
  relayObj["isPulse"] = relay.isPulse;
  relayObj["state"] = relay.state;
}

inline std::vector<RelayConfig> normalizeRelaySlots(const std::vector<RelayConfig>& relays) {
  std::vector<RelayConfig> normalized = makeDefaultRelaySlots();
  std::vector<bool> used(MAX_RELAYS + 1, false);
  uint8_t nextFallbackSlot = 1;

  auto allocateSlot = [&]() -> uint8_t {
    while (nextFallbackSlot <= MAX_RELAYS && used[nextFallbackSlot]) {
      ++nextFallbackSlot;
    }
    if (nextFallbackSlot > MAX_RELAYS) {
      return 0;
    }
    used[nextFallbackSlot] = true;
    return nextFallbackSlot++;
  };

  for (const auto& relay : relays) {
    uint8_t targetId = relay.id;
    if (targetId < 1 || targetId > MAX_RELAYS || used[targetId]) {
      targetId = allocateSlot();
    } else {
      used[targetId] = true;
      if (targetId >= nextFallbackSlot) {
        nextFallbackSlot = targetId + 1;
      }
    }

    if (targetId < 1 || targetId > MAX_RELAYS) {
      continue;
    }

    RelayConfig slot = normalized[targetId - 1];
    slot.id = targetId;

    if (!relay.name.isEmpty()) {
      slot.name = relay.name;
    }

    if (relay.pin >= 0) {
      slot.pin = relay.pin;
    }

    slot.activeLow = relay.activeLow;
    slot.pulseMs = relay.pulseMs;
    slot.pulseDurationMs = relay.pulseDurationMs;
    if (slot.pulseDurationMs == 0) {
      slot.pulseDurationMs = slot.pulseMs;
    }
    if (slot.pulseMs == 0 && slot.pulseDurationMs > 0) {
      slot.pulseMs = slot.pulseDurationMs;
    }
    slot.enabled = relay.enabled;
    slot.isPulse = relay.isPulse;
    slot.state = relay.state;

    normalized[targetId - 1] = slot;
  }

  return normalized;
}

inline void normalizeRelayConfiguration(AppConfig& config) {
  config.relays = normalizeRelaySlots(config.relays);
  config.relayCount = MAX_RELAYS;
}

#endif // PC_TYPES_H
