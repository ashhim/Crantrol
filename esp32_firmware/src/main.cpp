#include <Arduino.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <ETH.h>

// Include split headers
#include "pc_types.h"
#include "config.h"
#include "relay_manager.h"
#include "led_status_manager.h"
#include "ethernet_manager.h"
#include "firebase_client.h"
#include "captive_portal.h"

// ===================== GLOBAL OBJECTS =====================
AppConfig gAppConfig;
RuntimeState gRuntimeState;

RelayManager gRelayManager;
LedStatusManager gLedStatusManager(RGB_LED_PIN, STATUS_LED_PIN, NETWORK_LED_PIN, BUZZER_PIN, true);
EthernetManager gEthernetManager;
FirebaseClient gFirebaseClient;
CaptivePortal gCaptivePortal;

// ===================== TIMING VARIABLES =====================
uint32_t lastRelayStatusUpdate = 0;
uint32_t lastFirebaseSync = 0;
uint32_t lastNetworkStatusUpdate = 0;
uint32_t lastLedUpdate = 0;

// ===================== BOOT/SYNC FLAGS =====================
bool firstSyncDone = false;  // Skip command execution on first sync after boot

// ===================== PROTOTYPES =====================
void initializeRuntimeState();
void updateNetworkStatus();
void syncWithFirebase();
void logNetworkStatus();
void saveConfiguration();
void loadConfiguration();
String chipSuffix();
bool hasExecutedSystemRevision(const String& revision);
void rememberExecutedSystemRevision(const String& revision);

// ===================== SETUP =====================
void setup() {
  Serial.begin(SERIAL_BAUD_RATE);
  delay(250);
  
  Serial.println("\n\n===========================================");
  Serial.println("CRANTROL ESP32-S3-ETH PC Control Sketch");
  Serial.println("Starting up (Modular Mode)...");
  Serial.println("===========================================\n");
  
  // Initialize configuration from defaults
  gAppConfig = getDefaultConfig();
  
  // Resolve Device ID and AP Name
  String suffix = chipSuffix();
  gAppConfig.network.deviceId = "device_001";
  gAppConfig.network.apName = "PC-Control-" + suffix;
  
  // Load NVS config if available
  loadConfiguration();
  
  // Initialize Firebase Client configuration parameters
  gFirebaseClient.initialize(gAppConfig.firebase, gAppConfig.network.deviceId, gAppConfig.network.deviceName);
  
  // Initialize runtime state
  initializeRuntimeState();
  
  // Initialize relay pins
  gRelayManager.initializeRelays(gAppConfig.relays);
  Serial.printf("[SETUP] Relay Manager initialized with %d active relays\n", gAppConfig.relayCount);
  
  // Initialize indicators
  gLedStatusManager.initialize();
  Serial.println("[SETUP] LED status manager initialized");
  
  // Initialize W5500 Ethernet SPI and handlers
  gEthernetManager.initialize();
  Serial.println("[SETUP] Ethernet Manager initialized");
  
  // Set up Firebase connections
  gFirebaseClient.setRuntimeState(&gRuntimeState);
  Serial.println("[SETUP] Firebase Client initialized");
  
  // Start captive portal for AP setup
  gCaptivePortal.initialize(&gAppConfig, &gRuntimeState, &gRelayManager, &gFirebaseClient);
  gCaptivePortal.start();
  Serial.println("[SETUP] Captive Portal setup done");
}

// ===================== MAIN LOOP =====================
void loop() {
  uint32_t now = millis();
  
  // Run Ethernet task
  gEthernetManager.update();
  
  // Process status LEDs blinking status (every 100ms)
  if (now - lastLedUpdate > 100) {
    lastLedUpdate = now;
    updateNetworkStatus();
    gLedStatusManager.updateStatus(gEthernetManager.getStatus(), gFirebaseClient.getStatus());
    gLedStatusManager.update();
  }
  
  // Captive portal DNS/HTTP requests
  gCaptivePortal.update();
  
  // Execute momentary relay pulse logic
  gRelayManager.updatePulseTimers();
  
  // Sync Firebase status/desired queries if Internet link is active
  if (gEthernetManager.isInternetAvailable()) {
    // Authenticate if needed
    if (gFirebaseClient.getStatus() != FirebaseStatus::AUTHENTICATED && 
        (now - lastFirebaseSync > FIREBASE_RECONNECT_INTERVAL_MS || lastFirebaseSync == 0)) {
      lastFirebaseSync = now;
      gFirebaseClient.authenticate();
    }
    
    // Poll desired and push status (every 3 seconds)
    if (gFirebaseClient.getStatus() == FirebaseStatus::AUTHENTICATED && 
        now - lastFirebaseSync > 3000) {
      lastFirebaseSync = now;
      syncWithFirebase();
    }
  }
  
  // Periodic token updates
  if (now - lastRelayStatusUpdate > 2000) {
    lastRelayStatusUpdate = now;
    gFirebaseClient.update();
  }
  
  // Print status diagnostics to Serial Monitor (every 30 seconds)
  if (now - lastNetworkStatusUpdate > 30000) {
    lastNetworkStatusUpdate = now;
    logNetworkStatus();
  }
  
  delay(10);
}

// ===================== HELPER FUNCTIONS =====================

String chipSuffix() {
  uint64_t mac = ESP.getEfuseMac();
  char buffer[12];
  snprintf(buffer, sizeof(buffer), "%06llX", static_cast<unsigned long long>(mac & 0xFFFFFFULL));
  return String(buffer);
}

bool hasExecutedSystemRevision(const String& revision) {
  Preferences prefs;
  if (!prefs.begin(NVS_NAMESPACE, true)) {
    return false;
  }

  const String storedRevision = prefs.getString("last_system_revision", "");
  prefs.end();

  return !storedRevision.isEmpty() && storedRevision == revision;
}

void rememberExecutedSystemRevision(const String& revision) {
  Preferences prefs;
  if (!prefs.begin(NVS_NAMESPACE, false)) {
    return;
  }

  prefs.putString("last_system_revision", revision);
  prefs.end();
}

void initializeRuntimeState() {
  gRuntimeState.netStatus = NetworkStatus::NOT_PLUGGED;
  gRuntimeState.fbStatus = FirebaseStatus::DISCONNECTED;
  gRuntimeState.isEthernetPlugged = false;
  gRuntimeState.internetAvailable = false;
  gRuntimeState.firebaseReady = false;
  gRuntimeState.lastNetworkCheck = millis();
  gRuntimeState.lastFirebaseCheck = millis();
  gRuntimeState.macAddress = WiFi.macAddress().c_str();
  
  gRuntimeState.relayStates.clear();
  for (size_t i = 0; i < gAppConfig.relays.size(); i++) {
    RelayState state;
    state.relayId = gAppConfig.relays[i].id;
    state.isOn = false;
    state.lastCommandTime = 0;
    state.lastCommand = gAppConfig.relays[i].enabled ? "OFF" : "DISABLED";
    state.commandRevision = "";
    gRuntimeState.relayStates.push_back(state);
  }
}

void updateNetworkStatus() {
  gRuntimeState.isEthernetPlugged = gEthernetManager.isPlugged();
  gRuntimeState.internetAvailable = gEthernetManager.isInternetAvailable();
  gRuntimeState.localIp = gEthernetManager.getLocalIp().c_str();
  gRuntimeState.netStatus = gEthernetManager.getStatus();
  gRuntimeState.fbStatus = gFirebaseClient.getStatus();
  gRuntimeState.firebaseReady = (gFirebaseClient.getStatus() == FirebaseStatus::AUTHENTICATED);
  gRuntimeState.lastSeenAt = millis();
  gRuntimeState.heartbeatAt = millis();
  
  // Internet loss buzzer alert with 15-second debounce
  static bool wasInternetAvailable = false;
  static uint32_t internetLostAt = 0;
  static bool debounceActive = false;
  
  if (wasInternetAvailable && !gRuntimeState.internetAvailable) {
    // Internet just dropped — start debounce timer
    if (!debounceActive) {
      debounceActive = true;
      internetLostAt = millis();
    }
    // Only trigger alert after 15 seconds of continuous outage
    if (debounceActive && (millis() - internetLostAt > 15000)) {
      gLedStatusManager.startInternetLossAlert();
      debounceActive = false; // Alert started, stop debouncing
    }
  } else if (gRuntimeState.internetAvailable) {
    // Internet is available — cancel any pending debounce and stop alert
    debounceActive = false;
    if (wasInternetAvailable || gLedStatusManager.isInternetLossAlertActive()) {
      gLedStatusManager.stopInternetLossAlert();
    }
  }
  wasInternetAvailable = gRuntimeState.internetAvailable;
}

void syncWithFirebase() {
  // Read desired commands
  std::vector<FirebaseCommand> commands;
  if (gFirebaseClient.readDesiredCommands(commands)) {
    for (const auto& cmd : commands) {
      uint8_t relayId = 0;
      if (cmd.relayId.startsWith("relay")) {
        relayId = cmd.relayId.substring(5).toInt();
      } else {
        relayId = atoi(cmd.relayId.c_str());
      }
      if (relayId > 0) {
        if (!firstSyncDone) {
          // First sync after boot: store revisions but do NOT execute commands.
          // This prevents stale desired commands from turning relays ON after restart.
          gRelayManager.storeRevisionOnly(relayId, cmd.revision);
        } else {
          gRelayManager.executeCommand(relayId, cmd.command, cmd.revision);
        }
      }
    }
    
    // Handle buzzer command (ALERT button) — only after first sync
    if (firstSyncDone) {
      for (const auto& cmd : commands) {
        if (cmd.relayId == "buzzer") {
          if (cmd.command == "ON") {
            gLedStatusManager.setBuzzerOn(true);
            Serial.println("[ALERT] Buzzer ON (held)");
          } else if (cmd.command == "OFF") {
            gLedStatusManager.setBuzzerOn(false);
            Serial.println("[ALERT] Buzzer OFF (released)");
          }
        }
        if (cmd.relayId == "system") {
          if (cmd.command == "RESTART") {
            if (hasExecutedSystemRevision(cmd.revision)) {
              Serial.printf("[SYSTEM] Skipping already executed reset revision %s\n", cmd.revision.c_str());
            } else {
              rememberExecutedSystemRevision(cmd.revision);
              gRelayManager.clearRuntimeState();
              const bool cleared = gFirebaseClient.clearDesiredCommands();
              if (cleared) {
                Serial.println("[SYSTEM] Reset command acknowledged and runtime commands cleared");
              } else {
                Serial.println("[SYSTEM] Reset command acknowledged, but clearing Firebase commands failed");
              }
              gFirebaseClient.writeLogs("Hardware reset acknowledged and command cleared");
              gFirebaseClient.writeStatus(gRuntimeState, gAppConfig);
              delay(500);
              ESP.restart();
            }
          }
        }
      }
    }
    
    if (!firstSyncDone) {
      firstSyncDone = true;
      Serial.println("[SYNC] First sync complete — revisions stored, commands skipped (boot-to-OFF)");
    }
  }
  
  // Sync status
  gRuntimeState.relayStates = gRelayManager.getAllStates();
  gFirebaseClient.writeStatus(gRuntimeState, gAppConfig);
  
  // Write config revision if online changes occurred
  if (millis() - gAppConfig.lastSavedTime > 60000) {
    gFirebaseClient.writeDeviceConfig(gAppConfig);
  }
}

void logNetworkStatus() {
  Serial.println("\n[STATUS] Diagnostic Update:");
  Serial.printf("  Link Plugged: %s\n", gRuntimeState.isEthernetPlugged ? "Yes" : "No");
  Serial.printf("  Internet Ok: %s\n", gRuntimeState.internetAvailable ? "Yes" : "No");
  Serial.printf("  Firebase Authed: %s\n", gRuntimeState.firebaseReady ? "Yes" : "No");
  Serial.printf("  IP Address: %s\n", gRuntimeState.localIp.c_str());
  Serial.println("  Relay States:");
  for (const auto& state : gRuntimeState.relayStates) {
    Serial.printf("    Relay %d: %s (Rev: %s)\n", 
                  state.relayId, state.isOn ? "ON" : "OFF", state.commandRevision.c_str());
  }
}

void saveConfiguration() {
  Preferences prefs;
  if (!prefs.begin(NVS_NAMESPACE, false)) {
    Serial.println("[CONFIG] Failed to open NVS for writing");
    return;
  }
  
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  
  // Network config
  doc["deviceName"] = gAppConfig.network.deviceName.c_str();
  doc["deviceId"] = gAppConfig.network.deviceId.c_str();
  doc["roomId"] = gAppConfig.network.roomId.c_str();
  doc["roomCode"] = gAppConfig.network.roomCode.c_str();
  doc["apName"] = gAppConfig.network.apName.c_str();
  doc["apPassword"] = gAppConfig.network.apPassword.c_str();
  doc["externalLedEnabled"] = gAppConfig.network.externalLedEnabled;
  doc["rgbLedPin"] = gAppConfig.network.rgbLedPin;
  doc["statusLedPin"] = gAppConfig.network.statusLedPin;
  doc["networkLedPin"] = gAppConfig.network.networkLedPin;
  doc["buzzerPin"] = gAppConfig.network.buzzerPin;
  
  // Firebase config
  doc["firebaseApiKey"] = gAppConfig.firebase.apiKey.c_str();
  doc["firebaseAuthDomain"] = gAppConfig.firebase.authDomain.c_str();
  doc["firebaseDatabaseURL"] = gAppConfig.firebase.databaseURL.c_str();
  doc["firebaseProjectId"] = gAppConfig.firebase.projectId.c_str();
  doc["firebaseStorageBucket"] = gAppConfig.firebase.storageBucket.c_str();
  doc["firebaseMessagingSenderId"] = gAppConfig.firebase.messagingSenderId.c_str();
  doc["firebaseAppId"] = gAppConfig.firebase.appId.c_str();
  doc["firebaseEmail"] = gAppConfig.firebase.email.c_str();
  doc["firebasePassword"] = gAppConfig.firebase.password.c_str();
  
  // Relays
  doc["relayCount"] = gAppConfig.relayCount;
  JsonObject relaysObj = doc.createNestedObject("relays");
  for (const auto& relay : gAppConfig.relays) {
    JsonObject r = relaysObj.createNestedObject("relay" + String(relay.id));
    writeRelaySchema(r, relay);
  }
  
  String jsonStr;
  serializeJson(doc, jsonStr);
  
  prefs.putString(NVS_CONFIG_KEY, jsonStr);
  prefs.end();
  
  gAppConfig.lastSavedTime = millis();
  Serial.println("[CONFIG] Configuration saved to NVS");
}

void loadConfiguration() {
  Preferences prefs;
  if (!prefs.begin(NVS_NAMESPACE, true)) {
    Serial.println("[CONFIG] Failed to open NVS for reading");
    return;
  }
  
  String jsonStr = prefs.getString(NVS_CONFIG_KEY, "");
  prefs.end();
  
  if (jsonStr.length() > 0) {
    DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
    if (deserializeJson(doc, jsonStr) == DeserializationError::Ok) {
      // Load network config
      if (doc.containsKey("deviceName")) gAppConfig.network.deviceName = doc["deviceName"].as<String>().c_str();
      if (doc.containsKey("deviceId")) gAppConfig.network.deviceId = doc["deviceId"].as<String>().c_str();
      if (doc.containsKey("roomId")) gAppConfig.network.roomId = doc["roomId"].as<String>().c_str();
      if (doc.containsKey("roomCode")) gAppConfig.network.roomCode = doc["roomCode"].as<String>().c_str();
      if (doc.containsKey("apName")) gAppConfig.network.apName = doc["apName"].as<String>().c_str();
      if (doc.containsKey("apPassword")) gAppConfig.network.apPassword = doc["apPassword"].as<String>().c_str();
      if (doc.containsKey("externalLedEnabled")) gAppConfig.network.externalLedEnabled = doc["externalLedEnabled"].as<bool>();
      if (doc.containsKey("rgbLedPin")) gAppConfig.network.rgbLedPin = doc["rgbLedPin"].as<uint8_t>();
      if (doc.containsKey("statusLedPin")) gAppConfig.network.statusLedPin = doc["statusLedPin"].as<uint8_t>();
      if (doc.containsKey("networkLedPin")) gAppConfig.network.networkLedPin = doc["networkLedPin"].as<uint8_t>();
      if (doc.containsKey("buzzerPin")) gAppConfig.network.buzzerPin = doc["buzzerPin"].as<uint8_t>();
      
      // Load Firebase config
      if (doc.containsKey("firebaseApiKey")) gAppConfig.firebase.apiKey = doc["firebaseApiKey"].as<String>().c_str();
      if (doc.containsKey("firebaseAuthDomain")) gAppConfig.firebase.authDomain = doc["firebaseAuthDomain"].as<String>().c_str();
      if (doc.containsKey("firebaseDatabaseURL")) gAppConfig.firebase.databaseURL = doc["firebaseDatabaseURL"].as<String>().c_str();
      if (doc.containsKey("firebaseProjectId")) gAppConfig.firebase.projectId = doc["firebaseProjectId"].as<String>().c_str();
      if (doc.containsKey("firebaseStorageBucket")) gAppConfig.firebase.storageBucket = doc["firebaseStorageBucket"].as<String>().c_str();
      if (doc.containsKey("firebaseMessagingSenderId")) gAppConfig.firebase.messagingSenderId = doc["firebaseMessagingSenderId"].as<String>().c_str();
      if (doc.containsKey("firebaseAppId")) gAppConfig.firebase.appId = doc["firebaseAppId"].as<String>().c_str();
      if (doc.containsKey("firebaseEmail")) gAppConfig.firebase.email = doc["firebaseEmail"].as<String>().c_str();
      if (doc.containsKey("firebasePassword")) gAppConfig.firebase.password = doc["firebasePassword"].as<String>().c_str();
      
      // Load relays
      if (doc.containsKey("relays")) {
        std::vector<RelayConfig> loadedRelays;
        JsonVariantConst relaysValue = doc["relays"];
        if (relaysValue.is<JsonArrayConst>()) {
          JsonArrayConst relaysArray = relaysValue.as<JsonArrayConst>();
          uint8_t fallbackId = 1;
          for (JsonObjectConst relayObj : relaysArray) {
            if (!relayObj) continue;
            RelayConfig fallback = makeRelaySlot(fallbackId <= MAX_RELAYS ? fallbackId : MAX_RELAYS);
            RelayConfig relay = readRelaySchema(relayObj, fallback);
            if (relay.id == 0) {
              relay.id = fallbackId;
            }
            loadedRelays.push_back(relay);
            if (fallbackId < MAX_RELAYS) {
              ++fallbackId;
            }
          }
        } else if (relaysValue.is<JsonObjectConst>()) {
          JsonObjectConst relaysObj = relaysValue.as<JsonObjectConst>();
          for (JsonPairConst kv : relaysObj) {
            if (!kv.value().is<JsonObjectConst>()) continue;
            String key = kv.key().c_str();
            uint8_t fallbackId = 0;
            if (key.startsWith("relay")) {
              fallbackId = key.substring(5).toInt();
            }
            if (fallbackId < 1 || fallbackId > MAX_RELAYS) {
              fallbackId = loadedRelays.size() + 1;
            }
            RelayConfig fallback = makeRelaySlot(fallbackId);
            RelayConfig relay = readRelaySchema(kv.value().as<JsonObjectConst>(), fallback);
            if (relay.id < 1 || relay.id > MAX_RELAYS) {
              relay.id = fallbackId;
            }
            loadedRelays.push_back(relay);
          }
        }
        gAppConfig.relays = normalizeRelaySlots(loadedRelays);
        gAppConfig.relayCount = MAX_RELAYS;
      }
      
      normalizeRelayConfiguration(gAppConfig);
      
      Serial.println("[CONFIG] Configuration loaded from NVS");
    } else {
      Serial.println("[CONFIG] Failed to parse configuration from NVS");
    }
  } else {
    Serial.println("[CONFIG] No saved configuration found, using defaults");
  }
}
