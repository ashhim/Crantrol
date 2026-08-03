#include "captive_portal.h"
#include <Preferences.h>
#include <ArduinoJson.h>

CaptivePortal::CaptivePortal()
  : webServer(WEB_SERVER_PORT),
    apName(""),
    apPassword(""),
    isRunning(false),
    isAuthenticated(false) {
}

void CaptivePortal::initialize(AppConfig* config, RuntimeState* state, RelayManager* relayMgr, FirebaseClient* fbClient) {
  appConfig = config;
  runtimeState = state;
  relayManager = relayMgr;
  firebaseClient = fbClient;
  
  loadConfigFromNvs();
  
  // Load AP credentials from appConfig
  apName = appConfig->network.apName.c_str();
  apPassword = appConfig->network.apPassword.c_str();
}

void CaptivePortal::start() {
  Serial.println("[PORTAL] Starting Captive Portal...");
  
  // Start WiFi AP
  WiFi.mode(WIFI_AP);
  WiFi.softAP(apName.c_str(), apPassword.c_str());
  
  Serial.printf("[PORTAL] AP Started - SSID: %s, IP: %s\n", 
                apName.c_str(), WiFi.softAPIP().toString().c_str());
  
  // Setup DNS
  dnsServer.setErrorReplyCode(DNSReplyCode::NoError);
  dnsServer.start(53, "*", WiFi.softAPIP());
  
  // Setup web server routes
  setupRoutes();
  
  webServer.onNotFound([this]() { handleNotFound(); });
  webServer.begin();
  
  isRunning = true;
  Serial.println("[PORTAL] Captive Portal started successfully");
}

void CaptivePortal::stop() {
  Serial.println("[PORTAL] Stopping Captive Portal...");
  webServer.stop();
  dnsServer.stop();
  WiFi.softAPdisconnect(true);
  isRunning = false;
}

void CaptivePortal::update() {
  if (isRunning) {
    dnsServer.processNextRequest();
    webServer.handleClient();
  }
}

void CaptivePortal::setupRoutes() {
  webServer.on("/", HTTP_GET, [this]() { handleRoot(); });
  webServer.on("/login", HTTP_POST, [this]() { handleLogin(); });
  webServer.on("/dashboard", HTTP_GET, [this]() { handleDashboard(); });
  webServer.on("/settings", HTTP_GET, [this]() { handleSettings(); });
  webServer.on("/api/status", HTTP_GET, [this]() { handleApi(); });
  webServer.on("/api/config", HTTP_GET, [this]() {
    if (!isAuthenticated) {
      webServer.send(401, "application/json", "{\"error\":\"Not authenticated\"}");
      return;
    }
    // Return complete AppConfig as JSON
    DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
    
    // Network config
    doc["deviceName"] = appConfig->network.deviceName.c_str();
    doc["deviceId"] = appConfig->network.deviceId.c_str();
    doc["roomId"] = appConfig->network.roomId.c_str();
    doc["roomCode"] = appConfig->network.roomCode.c_str();
    doc["apName"] = appConfig->network.apName.c_str();
    doc["apPassword"] = appConfig->network.apPassword.c_str();
    doc["externalLedEnabled"] = appConfig->network.externalLedEnabled;
    doc["rgbLedPin"] = appConfig->network.rgbLedPin;
    doc["statusLedPin"] = appConfig->network.statusLedPin;
    doc["networkLedPin"] = appConfig->network.networkLedPin;
    doc["buzzerPin"] = appConfig->network.buzzerPin;
    
    // Firebase config
    doc["firebaseApiKey"] = appConfig->firebase.apiKey.c_str();
    doc["firebaseAuthDomain"] = appConfig->firebase.authDomain.c_str();
    doc["firebaseDatabaseURL"] = appConfig->firebase.databaseURL.c_str();
    doc["firebaseProjectId"] = appConfig->firebase.projectId.c_str();
    doc["firebaseStorageBucket"] = appConfig->firebase.storageBucket.c_str();
    doc["firebaseMessagingSenderId"] = appConfig->firebase.messagingSenderId.c_str();
    doc["firebaseAppId"] = appConfig->firebase.appId.c_str();
    doc["firebaseEmail"] = appConfig->firebase.email.c_str();
    doc["firebasePassword"] = appConfig->firebase.password.c_str();
    
    // Relays
    doc["relayCount"] = appConfig->relayCount;
    JsonObject relaysObj = doc.createNestedObject("relays");
    for (const auto& relay : appConfig->relays) {
      String key = "relay" + String(relay.id);
      JsonObject r = relaysObj.createNestedObject(key);
      writeRelaySchema(r, relay);
    }
    
    String output;
    serializeJson(doc, output);
    webServer.send(200, "application/json", output);
  });
  
  webServer.on("/api/save-settings", HTTP_POST, [this]() { handleSaveSettings(); });
  webServer.on("/api/save-relays", HTTP_POST, [this]() { handleSaveRelays(); });
  webServer.on("/api/control-relay", HTTP_POST, [this]() { handleControlRelay(); });
  webServer.on("/logout", HTTP_GET, [this]() { handleLogout(); });
  webServer.on("/restart", HTTP_POST, [this]() { handleRestart(); });
}

void CaptivePortal::handleNotFound() {
  webServer.sendHeader("Location", "/", true);
  webServer.send(302, "text/plain", "");
}

void CaptivePortal::handleRoot() {
  if (!isAuthenticated) {
    webServer.send(200, "text/html", getLoginHtml());
  } else {
    webServer.sendHeader("Location", "/dashboard", true);
    webServer.send(302, "text/plain", "");
  }
}

void CaptivePortal::handleLogin() {
  String email = webServer.arg("email");
  String password = webServer.arg("password");
  
  // Trim inputs from web form
  email.trim();
  password.trim();
  
  Serial.printf("[PORTAL] Web login attempt from: %s\n", webServer.client().remoteIP().toString().c_str());
  
  if (validateLogin(email, password)) {
    isAuthenticated = true;
    authToken = email;
    Serial.printf("[PORTAL] User authenticated: %s\n", email.c_str());
    webServer.sendHeader("Location", "/dashboard", true);
    webServer.send(302, "text/plain", "");
  } else {
    Serial.printf("[PORTAL] Failed login attempt for: %s\n", email.c_str());
    webServer.send(401, "text/html", getLoginHtml() + "<p style='color:red; text-align:center;'>Invalid credentials. Please check your email and password.</p>");
  }
}

void CaptivePortal::handleDashboard() {
  if (!isAuthenticated) {
    webServer.sendHeader("Location", "/", true);
    webServer.send(302, "text/plain", "");
    return;
  }
  webServer.send(200, "text/html", getDashboardHtml());
}

void CaptivePortal::handleSettings() {
  if (!isAuthenticated) {
    webServer.sendHeader("Location", "/", true);
    webServer.send(302, "text/plain", "");
    return;
  }
  webServer.send(200, "text/html", getSettingsHtml());
}

void CaptivePortal::handleSaveSettings() {
  if (!isAuthenticated) {
    webServer.send(401, "application/json", "{\"error\":\"Not authenticated\"}");
    return;
  }
  
  String body = webServer.arg("plain");
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  
  if (deserializeJson(doc, body) != DeserializationError::Ok) {
    webServer.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }
  
  // Update Network Config
  if (doc.containsKey("deviceName")) appConfig->network.deviceName = doc["deviceName"].as<String>().c_str();
  if (doc.containsKey("deviceId")) appConfig->network.deviceId = doc["deviceId"].as<String>().c_str();
  if (doc.containsKey("roomId")) appConfig->network.roomId = doc["roomId"].as<String>().c_str();
  if (doc.containsKey("roomCode")) appConfig->network.roomCode = doc["roomCode"].as<String>().c_str();
  if (doc.containsKey("apName")) appConfig->network.apName = doc["apName"].as<String>().c_str();
  if (doc.containsKey("apPassword")) appConfig->network.apPassword = doc["apPassword"].as<String>().c_str();
  if (doc.containsKey("externalLedEnabled")) appConfig->network.externalLedEnabled = doc["externalLedEnabled"].as<bool>();
  if (doc.containsKey("rgbLedPin")) appConfig->network.rgbLedPin = doc["rgbLedPin"].as<uint8_t>();
  if (doc.containsKey("statusLedPin")) appConfig->network.statusLedPin = doc["statusLedPin"].as<uint8_t>();
  if (doc.containsKey("networkLedPin")) appConfig->network.networkLedPin = doc["networkLedPin"].as<uint8_t>();
  if (doc.containsKey("buzzerPin")) appConfig->network.buzzerPin = doc["buzzerPin"].as<uint8_t>();
  
  // Update Firebase Config
  if (doc.containsKey("firebaseApiKey")) appConfig->firebase.apiKey = doc["firebaseApiKey"].as<String>().c_str();
  if (doc.containsKey("firebaseAuthDomain")) appConfig->firebase.authDomain = doc["firebaseAuthDomain"].as<String>().c_str();
  if (doc.containsKey("firebaseDatabaseURL")) appConfig->firebase.databaseURL = doc["firebaseDatabaseURL"].as<String>().c_str();
  if (doc.containsKey("firebaseProjectId")) appConfig->firebase.projectId = doc["firebaseProjectId"].as<String>().c_str();
  if (doc.containsKey("firebaseStorageBucket")) appConfig->firebase.storageBucket = doc["firebaseStorageBucket"].as<String>().c_str();
  if (doc.containsKey("firebaseMessagingSenderId")) appConfig->firebase.messagingSenderId = doc["firebaseMessagingSenderId"].as<String>().c_str();
  if (doc.containsKey("firebaseAppId")) appConfig->firebase.appId = doc["firebaseAppId"].as<String>().c_str();
  if (doc.containsKey("firebaseEmail")) appConfig->firebase.email = doc["firebaseEmail"].as<String>().c_str();
  if (doc.containsKey("firebasePassword")) appConfig->firebase.password = doc["firebasePassword"].as<String>().c_str();
  
  saveConfigToNvs();
  
  // Sync state variables in client objects if they exist
  if (firebaseClient) {
    firebaseClient->initialize(appConfig->firebase, String(appConfig->network.deviceId.c_str()));
    firebaseClient->setRuntimeState(runtimeState);
  }
  
  webServer.send(200, "application/json", "{\"status\":\"OK\"}");
}

void CaptivePortal::handleSaveRelays() {
  if (!isAuthenticated) {
    webServer.send(401, "application/json", "{\"error\":\"Not authenticated\"}");
    return;
  }
  
  String body = webServer.arg("plain");
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  
  if (deserializeJson(doc, body) != DeserializationError::Ok) {
    webServer.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }
  
  std::vector<RelayConfig> loadedRelays;
  JsonVariantConst relaysValue = doc["relays"];
  if (relaysValue.is<JsonArrayConst>()) {
    JsonArrayConst relayArray = relaysValue.as<JsonArrayConst>();
    uint8_t fallbackId = 1;
    for (JsonObjectConst relayObj : relayArray) {
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
    JsonObjectConst relayObjMap = relaysValue.as<JsonObjectConst>();
    for (JsonPairConst kv : relayObjMap) {
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
  
  appConfig->relays = normalizeRelaySlots(loadedRelays);
  appConfig->relayCount = MAX_RELAYS;
  
  saveConfigToNvs();
  
  if (relayManager) {
    relayManager->initializeRelays(appConfig->relays);
  }
  
  webServer.send(200, "application/json", "{\"status\":\"OK\"}");
}

void CaptivePortal::handleRestart() {
  webServer.send(200, "application/json", "{\"status\":\"Restarting...\"}");
  delay(1000);
  ESP.restart();
}

void CaptivePortal::handleLogout() {
  isAuthenticated = false;
  authToken = "";
  webServer.sendHeader("Location", "/", true);
  webServer.send(302, "text/plain", "");
}

void CaptivePortal::handleApi() {
  webServer.send(200, "application/json", getJsonStatus());
}

void CaptivePortal::handleControlRelay() {
  if (!isAuthenticated) {
    webServer.send(401, "application/json", "{\"error\":\"Not authenticated\"}");
    return;
  }
  String idStr = webServer.arg("id");
  String command = webServer.arg("command");
  if (idStr.isEmpty() || command.isEmpty()) {
    webServer.send(400, "application/json", "{\"error\":\"Missing parameters\"}");
    return;
  }
  uint8_t relayId = idStr.toInt();
  
  if (relayManager) {
    relayManager->executeCommand(relayId, command, "portal_" + String(millis()));
  }
  
  if (runtimeState && relayManager) {
    runtimeState->relayStates = relayManager->getAllStates();
    if (firebaseClient) {
      firebaseClient->writeStatus(*runtimeState, *appConfig);
    }
  }
  
  webServer.send(200, "application/json", "{\"status\":\"OK\"}");
}

String CaptivePortal::getLoginHtml() {
  return R"raw(
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CRANTROL - Login</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 20px;
    }
    .login-container {
      background: white;
      border-radius: 12px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.25);
      padding: 40px;
      width: 100%;
      max-width: 400px;
    }
    h1 {
      text-align: center;
      color: #333;
      margin-bottom: 25px;
      font-size: 26px;
      font-weight: 700;
    }
    .form-group {
      margin-bottom: 20px;
    }
    label {
      display: block;
      margin-bottom: 8px;
      color: #555;
      font-weight: 600;
    }
    input[type="email"],
    input[type="password"] {
      width: 100%;
      padding: 12px 15px;
      border: 2px solid #eaeaea;
      border-radius: 8px;
      font-size: 14px;
      transition: all 0.3s;
    }
    input[type="email"]:focus,
    input[type="password"]:focus {
      outline: none;
      border-color: #667eea;
    }
    button {
      width: 100%;
      padding: 12px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s;
      box-shadow: 0 4px 10px rgba(118, 75, 162, 0.3);
    }
    button:hover {
      transform: translateY(-1px);
      box-shadow: 0 6px 15px rgba(118, 75, 162, 0.4);
    }
    .info {
      text-align: center;
      margin-top: 20px;
      color: #777;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="login-container">
    <h1>CRANTROL Portal</h1>
    <form method="POST" action="/login">
      <div class="form-group">
        <label for="email">Email</label>
        <input type="email" id="email" name="email" required placeholder="your-email@example.com">
      </div>
      <div class="form-group">
        <label for="password">Password</label>
        <input type="password" id="password" name="password" required placeholder="your-password">
      </div>
      <button type="submit">Login</button>
    </form>
    <div class="info">
      Please sign in with your Firebase account.<br><br>
      For initial setup (or if offline), use the default local admin credentials:<br>
      <strong>Email:</strong> admin@hashpc.local<br>
      <strong>Password:</strong> admin1234
    </div>
  </div>
</body>
</html>
)raw";
}

String CaptivePortal::getDashboardHtml() {
  return R"raw(
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CRANTROL - Dashboard</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: #f4f6fa;
      color: #333;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 15px 30px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }
    .header h1 { font-size: 22px; font-weight: 700; }
    .nav-buttons a {
      color: white;
      text-decoration: none;
      margin-left: 15px;
      padding: 8px 16px;
      background: rgba(255,255,255,0.18);
      border-radius: 6px;
      font-weight: 600;
      transition: all 0.3s;
    }
    .nav-buttons a:hover {
      background: rgba(255,255,255,0.3);
    }
    .container {
      max-width: 1200px;
      margin: 30px auto;
      padding: 0 20px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 25px;
    }
    .card {
      background: white;
      border-radius: 10px;
      padding: 25px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.05);
    }
    .card h2 {
      margin-bottom: 20px;
      color: #764ba2;
      font-size: 18px;
      font-weight: 700;
      border-bottom: 2px solid #f0f0f2;
      padding-bottom: 8px;
    }
    .status-item {
      display: flex;
      justify-content: space-between;
      padding: 12px 0;
      border-bottom: 1px solid #eaeaea;
    }
    .status-item:last-child {
      border-bottom: none;
    }
    .label { color: #666; font-weight: 500; }
    .value { font-weight: 600; display: flex; align-items: center; }
    .indicator {
      display: inline-block;
      width: 10px;
      height: 10px;
      border-radius: 50%;
      margin-left: 10px;
    }
    .indicator.active { background: #2ecc71; }
    .indicator.inactive { background: #e74c3c; }
    
    .relay-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
      gap: 15px;
    }
    .relay-item-card {
      padding: 15px;
      text-align: center;
      border: 2px solid #eaeaea;
      border-radius: 8px;
      background: white;
      transition: all 0.3s;
    }
    .relay-item-card.on {
      background: #eefcf4;
      border-color: #2ecc71;
    }
    .relay-item-card strong {
      display: block;
      font-size: 16px;
      color: #333;
    }
    .relay-item-card p {
      font-size: 13px;
      color: #666;
      margin: 5px 0;
    }
    .relay-status-pill {
      display: inline-block;
      padding: 3px 8px;
      font-size: 11px;
      font-weight: 700;
      color: white;
      background: #95a5a6;
      border-radius: 4px;
    }
    .relay-item-card.on .relay-status-pill {
      background: #2ecc71;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>CRANTROL Dashboard</h1>
    <div class="nav-buttons">
      <a href="/settings">Settings</a>
      <a href="/logout">Logout</a>
    </div>
  </div>
  
  <div class="container">
    <div class="grid">
      <div class="card">
        <h2>Network Status</h2>
        <div id="network-status"></div>
      </div>
      
      <div class="card">
        <h2>Firebase Connection</h2>
        <div id="firebase-status"></div>
      </div>
      
      <div class="card">
        <h2>Relay Status</h2>
        <div class="relay-grid" id="relay-grid"></div>
      </div>
    </div>
  </div>
  
  <script>
    function relayDefaults(id) {
      const defaults = {
        1: { id: 1, name: 'PC Power', pin: 21, activeLow: true, pulseMs: 350, pulseDurationMs: 350, enabled: true, isPulse: false, state: false, isOn: false },
        2: { id: 2, name: 'Monitor 1', pin: 17, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        3: { id: 3, name: 'Monitor 2', pin: 16, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        4: { id: 4, name: 'Motherboard Power Button', pin: 18, activeLow: true, pulseMs: 250, pulseDurationMs: 250, enabled: true, isPulse: false, state: false, isOn: false },
        5: { id: 5, name: 'Relay 5', pin: 15, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        6: { id: 6, name: 'Relay 6', pin: 3, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        7: { id: 7, name: 'Relay 7', pin: 2, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        8: { id: 8, name: 'Relay 8', pin: 1, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        9: { id: 9, name: 'Power', pin: 0, activeLow: true, pulseMs: 4000, pulseDurationMs: 4000, enabled: true, isPulse: true, state: false, isOn: false },
        10: { id: 10, name: 'Reset', pin: 44, activeLow: true, pulseMs: 1000, pulseDurationMs: 1000, enabled: true, isPulse: true, state: false, isOn: false }
      };
      return defaults[id] || {
        id,
        name: `Relay ${id}`,
        pin: 0,
        activeLow: true,
        pulseMs: 0,
        pulseDurationMs: 0,
        enabled: false,
        isPulse: false,
        state: false,
        isOn: false
      };
    }

    function relayIdFromKey(key, fallback) {
      if (typeof key !== 'string') return fallback;
      const parsed = parseInt(key.replace(/^relay/i, ''), 10);
      return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
    }

    function normalizeRelayCollection(relays) {
      const slots = Array.from({ length: 10 }, (_, index) => relayDefaults(index + 1));
      const entries = [];

      if (Array.isArray(relays)) {
        relays.forEach((relay, index) => {
          if (relay && typeof relay === 'object') {
            entries.push({ ...relay, __key: index + 1 });
          }
        });
      } else if (relays && typeof relays === 'object') {
        Object.entries(relays).forEach(([key, value]) => {
          if (value && typeof value === 'object') {
            entries.push({ ...value, __key: key });
          }
        });
      }

      const used = new Set();
      let fallback = 1;

      for (const entry of entries) {
        let id = Number.parseInt(entry.id ?? relayIdFromKey(entry.__key, fallback), 10);
        if (!Number.isFinite(id) || id < 1 || id > 10 || used.has(id)) {
          while (fallback <= 10 && used.has(fallback)) fallback += 1;
          id = fallback;
        }

        if (!Number.isFinite(id) || id < 1 || id > 10) {
          continue;
        }

        used.add(id);
        if (id >= fallback) {
          fallback = id + 1;
        }

        const slot = { ...relayDefaults(id) };
        const name = `${entry.name ?? ''}`.trim();
        if (name) slot.name = name;

        if (entry.pin !== undefined) {
          const pin = Number.parseInt(entry.pin, 10);
          if (!Number.isNaN(pin) && (id > 4 || pin !== 0)) {
            slot.pin = pin;
          }
        }

        if (entry.activeLow !== undefined) slot.activeLow = !!entry.activeLow;

        if (entry.pulseMs !== undefined) {
          const pulseMs = Number.parseInt(entry.pulseMs, 10);
          if (!Number.isNaN(pulseMs)) slot.pulseMs = pulseMs;
        }

        if (entry.pulseDurationMs !== undefined) {
          const pulseDurationMs = Number.parseInt(entry.pulseDurationMs, 10);
          if (!Number.isNaN(pulseDurationMs)) slot.pulseDurationMs = pulseDurationMs;
        }

        if (slot.pulseDurationMs === 0) slot.pulseDurationMs = slot.pulseMs;
        if (slot.pulseMs === 0 && slot.pulseDurationMs > 0) slot.pulseMs = slot.pulseDurationMs;

        if (entry.enabled !== undefined) slot.enabled = !!entry.enabled;
        if (entry.isPulse !== undefined) slot.isPulse = !!entry.isPulse;
        if (entry.state !== undefined) slot.state = !!entry.state;
        if (entry.isOn !== undefined) slot.state = !!entry.isOn;
        slot.isOn = slot.state;

        slots[id - 1] = slot;
      }

      return slots;
    }

    async function updateStatus() {
      try {
        const response = await fetch('/api/status');
        const data = await response.json();
        
        document.getElementById('network-status').innerHTML = `
          <div class="status-item">
            <span class="label">Ethernet Link</span>
            <span class="value">${data.ethernetPlugged ? 'Connected' : 'Disconnected'}
              <span class="indicator ${data.ethernetPlugged ? 'active' : 'inactive'}"></span>
            </span>
          </div>
          <div class="status-item">
            <span class="label">Internet Link</span>
            <span class="value">${data.internetAvailable ? 'Available' : 'Down'}
              <span class="indicator ${data.internetAvailable ? 'active' : 'inactive'}"></span>
            </span>
          </div>
          <div class="status-item">
            <span class="label">Local IP</span>
            <span class="value" style="font-family:monospace;">${data.localIp || 'N/A'}</span>
          </div>
        `;
        
        document.getElementById('firebase-status').innerHTML = `
          <div class="status-item">
            <span class="label">Firebase API Connection</span>
            <span class="value">${data.firebaseReady ? 'Authenticated' : 'Disconnected'}
              <span class="indicator ${data.firebaseReady ? 'active' : 'inactive'}"></span>
            </span>
          </div>
          <div class="status-item">
            <span class="label">Token State</span>
            <span class="value">${data.firebaseStatus === 2 ? 'Active' : 'Unauthenticated'}</span>
          </div>
        `;
        
        const relayGrid = document.getElementById('relay-grid');
        const relaysArray = normalizeRelayCollection(data.relays);
        relayGrid.innerHTML = relaysArray.map(relay => {
          const isOn = !!(relay.state ?? relay.isOn);
          const isEnabled = relay.enabled !== false;
          const canPulse = isEnabled && relay.isPulse;
          const label = relay.id >= 1 && relay.id <= 8 ? `PLUG${relay.id}` : (relay.name || `Relay ${relay.id}`);

          return `
            <div class="relay-item-card ${isOn ? 'on' : ''}" style="display: flex; flex-direction: column; align-items: center; justify-content: space-between; min-height: 120px; padding: 12px; opacity: ${isEnabled ? '1' : '0.72'};">
              <strong>${label}</strong>
              <p style="margin: 2px 0 6px 0; font-size: 13px;">${relay.name || 'Unnamed'}</p>
              <div style="display: flex; gap: 6px; flex-wrap: wrap; justify-content: center; margin-bottom: 8px;">
                <span class="relay-status-pill">${isOn ? 'ON' : 'OFF'}</span>
                <span class="relay-status-pill" style="background: ${isEnabled ? '#6c757d' : '#9aa0a6'};">${isEnabled ? 'Enabled' : 'Disabled'}</span>
              </div>
              <div style="display: flex; gap: 6px; flex-wrap: wrap; justify-content: center;">
                ${canPulse ? `<button ${isEnabled ? '' : 'disabled'} onclick="controlRelay(${relay.id}, 'PULSE')" style="padding: 4px 8px; font-size: 11px; background: #3498db; color: white; border: none; border-radius: 4px; cursor: pointer; min-width: 68px; opacity: ${isEnabled ? '1' : '0.5'};">Pulse</button>` : `<button ${isEnabled ? '' : 'disabled'} onclick="controlRelay(${relay.id}, '${isOn ? 'OFF' : 'ON'}')" style="padding: 4px 8px; font-size: 11px; background: ${isOn ? '#e74c3c' : '#2ecc71'}; color: white; border: none; border-radius: 4px; cursor: pointer; min-width: 60px; opacity: ${isEnabled ? '1' : '0.5'};">${isOn ? 'Turn Off' : 'Turn On'}</button>`}
              </div>
            </div>
          `;
        }).join('');
      } catch (error) {
        console.error('Failed to update dashboard status:', error);
      }
    }

    async function controlRelay(id, command) {
      try {
        const response = await fetch('/api/control-relay', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: new URLSearchParams({ id: id, command: command })
        });
        const res = await response.json();
        if (res.status === 'OK') {
          updateStatus();
        } else {
          alert('Control failed: ' + (res.error || 'Unknown error'));
        }
      } catch (error) {
        console.error('Error controlling relay:', error);
      }
    }
    
    updateStatus();
    setInterval(updateStatus, 3000);
  </script>
</body>
</html>
)raw";
}

String CaptivePortal::getSettingsHtml() {
  return R"raw(
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>HashPC - Configuration</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: #f4f6fa;
      padding-bottom: 50px;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 15px 30px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }
    .header h1 { font-size: 22px; font-weight: 700; }
    .header a { color: white; text-decoration: none; margin-left: 15px; font-weight: 600; }
    .container {
      max-width: 850px;
      margin: 30px auto;
      padding: 0 20px;
    }
    .card {
      background: white;
      border-radius: 10px;
      padding: 30px;
      margin-bottom: 25px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.05);
    }
    h2 {
      color: #764ba2;
      margin-bottom: 20px;
      font-size: 19px;
      font-weight: 700;
      border-bottom: 2px solid #f0f0f2;
      padding-bottom: 8px;
    }
    .form-group {
      margin-bottom: 18px;
    }
    label {
      display: block;
      margin-bottom: 6px;
      color: #555;
      font-weight: 600;
      font-size: 14px;
    }
    input[type="text"],
    input[type="email"],
    input[type="password"],
    input[type="number"] {
      width: 100%;
      padding: 10px 12px;
      border: 1px solid #ddd;
      border-radius: 6px;
      font-size: 14px;
      transition: all 0.3s;
    }
    input:focus {
      outline: none;
      border-color: #667eea;
      box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.15);
    }
    .form-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 15px;
    }
    button {
      padding: 10px 20px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      border-radius: 6px;
      cursor: pointer;
      font-weight: 600;
      transition: all 0.3s;
      box-shadow: 0 4px 10px rgba(118, 75, 162, 0.2);
    }
    button:hover {
      transform: translateY(-1px);
      box-shadow: 0 6px 15px rgba(118, 75, 162, 0.3);
    }
    .relay-item {
      background: #f8f9fc;
      padding: 20px;
      border-radius: 8px;
      margin-bottom: 15px;
      border-left: 4px solid #667eea;
    }
    .checkbox-group {
      display: flex;
      align-items: center;
      margin: 10px 0;
    }
    .checkbox-group input {
      width: 18px;
      height: 18px;
      margin-right: 10px;
      cursor: pointer;
    }
    .checkbox-group label {
      margin-bottom: 0;
      user-select: none;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>HashPC Settings</h1>
    <div>
      <a href="/dashboard">Dashboard</a>
      <a href="/logout">Logout</a>
    </div>
  </div>
  
  <div class="container">
    <!-- Device config -->
    <div class="card">
      <h2>Device Settings</h2>
      <div class="form-row">
        <div class="form-group">
          <label>Device Name</label>
          <input type="text" id="deviceName">
        </div>
        <div class="form-group">
          <label>Device ID</label>
          <input type="text" id="deviceId">
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Room ID</label>
          <input type="text" id="roomId">
        </div>
        <div class="form-group">
          <label>Room Code</label>
          <input type="text" id="roomCode">
        </div>
      </div>
      <button onclick="saveDeviceSettings()">Save Device Settings</button>
    </div>
    
    <!-- Wifi config -->
    <div class="card">
      <h2>Wi-Fi AP Settings</h2>
      <div class="form-row">
        <div class="form-group">
          <label>AP SSID</label>
          <input type="text" id="apName">
        </div>
        <div class="form-group">
          <label>AP Password</label>
          <input type="password" id="apPassword">
        </div>
      </div>
      <button onclick="saveWifiSettings()">Save Wi-Fi Settings</button>
    </div>
    
    <!-- Firebase config -->
    <div class="card">
      <h2>Firebase Configuration</h2>
      <div class="form-group">
        <label>API Key</label>
        <input type="text" id="firebaseApiKey">
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Auth Domain</label>
          <input type="text" id="firebaseAuthDomain">
        </div>
        <div class="form-group">
          <label>Database URL</label>
          <input type="text" id="firebaseDatabaseURL">
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Project ID</label>
          <input type="text" id="firebaseProjectId">
        </div>
        <div class="form-group">
          <label>Storage Bucket</label>
          <input type="text" id="firebaseStorageBucket">
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Messaging Sender ID</label>
          <input type="text" id="firebaseMessagingSenderId">
        </div>
        <div class="form-group">
          <label>App ID</label>
          <input type="text" id="firebaseAppId">
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Email</label>
          <input type="email" id="firebaseEmail">
        </div>
        <div class="form-group">
          <label>Password</label>
          <input type="password" id="firebasePassword">
        </div>
      </div>
      <button onclick="saveFirebaseSettings()">Save Firebase Configuration</button>
    </div>
    
    <!-- Hardware config -->
    <div class="card">
      <h2>Hardware Pins & LEDs</h2>
      <div class="form-row">
        <div class="form-group">
          <label>RGB Pin</label>
          <input type="number" id="rgbLedPin">
        </div>
        <div class="form-group">
          <label>Buzzer Pin</label>
          <input type="number" id="buzzerPin">
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Status LED Pin</label>
          <input type="number" id="statusLedPin">
        </div>
        <div class="form-group">
          <label>Network LED Pin</label>
          <input type="number" id="networkLedPin">
        </div>
      </div>
      <div class="checkbox-group">
        <input type="checkbox" id="externalLedEnabled">
        <label for="externalLedEnabled">Enable External Status LEDs</label>
      </div>
      <button onclick="saveHardwareSettings()">Save Hardware Settings</button>
    </div>
    
    <!-- Relay Configuration Section -->
    <div class="card">
      <h2>Relay Configuration</h2>
      <div class="form-group">
        <label>Total Relays Count</label>
        <input type="number" id="relayCount" min="1" max="10" onchange="adjustRelayForm()">
      </div>
      <div id="relay-config-list"></div>
      <button onclick="saveRelayConfiguration()">Save Relay Configuration</button>
    </div>
    
    <div class="card" style="text-align: center;">
      <button onclick="restartDevice()" style="background:linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);">Restart Device</button>
    </div>
  </div>
  
  <script>
    let globalConfig = {};

    function relayDefaults(id) {
      const defaults = {
        1: { id: 1, name: 'PC Power', pin: 21, activeLow: true, pulseMs: 350, pulseDurationMs: 350, enabled: true, isPulse: false, state: false, isOn: false },
        2: { id: 2, name: 'Monitor 1', pin: 17, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        3: { id: 3, name: 'Monitor 2', pin: 16, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        4: { id: 4, name: 'Motherboard Power Button', pin: 18, activeLow: true, pulseMs: 250, pulseDurationMs: 250, enabled: true, isPulse: false, state: false, isOn: false },
        5: { id: 5, name: 'Relay 5', pin: 15, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        6: { id: 6, name: 'Relay 6', pin: 3, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        7: { id: 7, name: 'Relay 7', pin: 2, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        8: { id: 8, name: 'Relay 8', pin: 1, activeLow: true, pulseMs: 0, pulseDurationMs: 0, enabled: true, isPulse: false, state: false, isOn: false },
        9: { id: 9, name: 'Power', pin: 0, activeLow: true, pulseMs: 4000, pulseDurationMs: 4000, enabled: true, isPulse: true, state: false, isOn: false },
        10: { id: 10, name: 'Reset', pin: 44, activeLow: true, pulseMs: 1000, pulseDurationMs: 1000, enabled: true, isPulse: true, state: false, isOn: false }
      };
      return defaults[id] || {
        id,
        name: `Relay ${id}`,
        pin: 0,
        activeLow: true,
        pulseMs: 0,
        pulseDurationMs: 0,
        enabled: false,
        isPulse: false,
        state: false,
        isOn: false
      };
    }

    function relayIdFromKey(key, fallback) {
      if (typeof key !== 'string') return fallback;
      const parsed = parseInt(key.replace(/^relay/i, ''), 10);
      return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
    }

    function normalizeRelayCollection(relays) {
      const slots = Array.from({ length: 10 }, (_, index) => relayDefaults(index + 1));
      const entries = [];

      if (Array.isArray(relays)) {
        relays.forEach((relay, index) => {
          if (relay && typeof relay === 'object') {
            entries.push({ ...relay, __key: index + 1 });
          }
        });
      } else if (relays && typeof relays === 'object') {
        Object.entries(relays).forEach(([key, value]) => {
          if (value && typeof value === 'object') {
            entries.push({ ...value, __key: key });
          }
        });
      }

      const used = new Set();
      let fallback = 1;

      for (const entry of entries) {
        let id = Number.parseInt(entry.id ?? relayIdFromKey(entry.__key, fallback), 10);
        if (!Number.isFinite(id) || id < 1 || id > 10 || used.has(id)) {
          while (fallback <= 10 && used.has(fallback)) fallback += 1;
          id = fallback;
        }

        if (!Number.isFinite(id) || id < 1 || id > 10) {
          continue;
        }

        used.add(id);
        if (id >= fallback) {
          fallback = id + 1;
        }

        const slot = { ...relayDefaults(id) };
        const name = `${entry.name ?? ''}`.trim();
        if (name) slot.name = name;

        if (entry.pin !== undefined) {
          const pin = Number.parseInt(entry.pin, 10);
          if (!Number.isNaN(pin) && (id > 4 || pin !== 0)) {
            slot.pin = pin;
          }
        }

        if (entry.activeLow !== undefined) slot.activeLow = !!entry.activeLow;

        if (entry.pulseMs !== undefined) {
          const pulseMs = Number.parseInt(entry.pulseMs, 10);
          if (!Number.isNaN(pulseMs)) slot.pulseMs = pulseMs;
        }

        if (entry.pulseDurationMs !== undefined) {
          const pulseDurationMs = Number.parseInt(entry.pulseDurationMs, 10);
          if (!Number.isNaN(pulseDurationMs)) slot.pulseDurationMs = pulseDurationMs;
        }

        if (slot.pulseDurationMs === 0) slot.pulseDurationMs = slot.pulseMs;
        if (slot.pulseMs === 0 && slot.pulseDurationMs > 0) slot.pulseMs = slot.pulseDurationMs;

        if (entry.enabled !== undefined) slot.enabled = !!entry.enabled;
        if (entry.isPulse !== undefined) slot.isPulse = !!entry.isPulse;
        if (entry.state !== undefined) slot.state = !!entry.state;
        if (entry.isOn !== undefined) slot.state = !!entry.isOn;
        slot.isOn = slot.state;

        slots[id - 1] = slot;
      }

      return slots;
    }
    
    async function loadConfig() {
      try {
        const response = await fetch('/api/config');
        globalConfig = await response.json();
        
        // Populate inputs
        document.getElementById('deviceName').value = globalConfig.deviceName || '';
        document.getElementById('deviceId').value = globalConfig.deviceId || '';
        document.getElementById('roomId').value = globalConfig.roomId || '';
        document.getElementById('roomCode').value = globalConfig.roomCode || '';
        
        document.getElementById('apName').value = globalConfig.apName || '';
        document.getElementById('apPassword').value = globalConfig.apPassword || '';
        
        document.getElementById('firebaseApiKey').value = globalConfig.firebaseApiKey || '';
        document.getElementById('firebaseAuthDomain').value = globalConfig.firebaseAuthDomain || '';
        document.getElementById('firebaseDatabaseURL').value = globalConfig.firebaseDatabaseURL || '';
        document.getElementById('firebaseProjectId').value = globalConfig.firebaseProjectId || '';
        document.getElementById('firebaseStorageBucket').value = globalConfig.firebaseStorageBucket || '';
        document.getElementById('firebaseMessagingSenderId').value = globalConfig.firebaseMessagingSenderId || '';
        document.getElementById('firebaseAppId').value = globalConfig.firebaseAppId || '';
        document.getElementById('firebaseEmail').value = globalConfig.firebaseEmail || '';
        document.getElementById('firebasePassword').value = globalConfig.firebasePassword || '';
        
        document.getElementById('rgbLedPin').value = globalConfig.rgbLedPin || 0;
        document.getElementById('buzzerPin').value = globalConfig.buzzerPin || 0;
        document.getElementById('statusLedPin').value = globalConfig.statusLedPin || 0;
        document.getElementById('networkLedPin').value = globalConfig.networkLedPin || 0;
        document.getElementById('externalLedEnabled').checked = globalConfig.externalLedEnabled || false;
        
        document.getElementById('relayCount').value = Math.max(globalConfig.relayCount || 10, 10);
        
        renderRelays(normalizeRelayCollection(globalConfig.relays));
      } catch (err) {
        console.error('Failed to load settings:', err);
      }
    }
    
    function renderRelays(relays) {
      const container = document.getElementById('relay-config-list');
      container.innerHTML = '';
      
      relays.forEach(relay => {
        container.appendChild(createRelayCard(relay));
      });
    }
    
    function createRelayCard(relay) {
      const card = document.createElement('div');
      card.className = 'relay-item';
      card.dataset.id = relay.id;
      const isEnabled = relay.enabled !== false;
      
      card.innerHTML = `
        <h4 style="margin-bottom:12px; color:#667eea;">Relay ${relay.id} Settings</h4>
        <input type="hidden" class="relay-id" value="${relay.id}">
        <input type="hidden" class="relay-state" value="${relay.state || relay.isOn ? 1 : 0}">
        <div class="form-row">
          <div class="form-group">
            <label>Relay Name</label>
            <input type="text" class="relay-name" value="${relay.name || ''}">
          </div>
          <div class="form-group">
            <label>GPIO Pin</label>
            <input type="number" class="relay-pin" value="${relay.pin ?? 0}">
          </div>
        </div>
        <div class="form-row">
          <div class="form-group checkbox-group" style="margin-top:25px;">
            <input type="checkbox" class="relay-active-low" id="activeLow-${relay.id}" ${relay.activeLow ? 'checked' : ''}>
            <label for="activeLow-${relay.id}">Active Low</label>
          </div>
          <div class="form-group checkbox-group" style="margin-top:25px;">
            <input type="checkbox" class="relay-enabled" id="enabled-${relay.id}" ${isEnabled ? 'checked' : ''}>
            <label for="enabled-${relay.id}">Enabled</label>
          </div>
        </div>
        <div class="form-row">
          <div class="form-group checkbox-group" style="margin-top:25px;">
            <input type="checkbox" class="relay-is-pulse" id="pulse-${relay.id}" ${relay.isPulse ? 'checked' : ''} onchange="togglePulseField(${relay.id})">
            <label for="pulse-${relay.id}">Pulse Control</label>
          </div>
          <div class="form-group relay-pulse-dur-group" id="durGroup-${relay.id}" style="display:${relay.isPulse ? 'block' : 'none'};">
            <label>Pulse Duration (ms)</label>
            <input type="number" class="relay-pulse-duration" value="${relay.pulseDurationMs || 0}">
          </div>
        </div>
      `;
      return card;
    }
    
    function togglePulseField(relayId) {
      const isPulse = document.getElementById(`pulse-${relayId}`).checked;
      document.getElementById(`durGroup-${relayId}`).style.display = isPulse ? 'block' : 'none';
    }
    
    function adjustRelayForm() {
      const count = Math.min(Math.max(parseInt(document.getElementById('relayCount').value) || 10, 1), 10);
      const container = document.getElementById('relay-config-list');
      const currentCards = container.querySelectorAll('.relay-item');
      const currentCount = currentCards.length;
      
      if (count > currentCount) {
        for (let i = currentCount + 1; i <= count; i++) {
          container.appendChild(createRelayCard({
            ...relayDefaults(i)
          }));
        }
      } else if (count < currentCount) {
        document.getElementById('relayCount').value = currentCount;
      }
    }
    
    async function saveSettings(payload) {
      try {
        const response = await fetch('/api/save-settings', {
          method: 'POST',
          body: JSON.stringify(payload),
          headers: { 'Content-Type': 'application/json' }
        });
        if (response.ok) {
          alert('Device parameters saved successfully!');
        } else {
          alert('Failed to save parameters.');
        }
      } catch (err) {
        alert('Error: ' + err);
      }
    }
    
    function saveDeviceSettings() {
      saveSettings({
        deviceName: document.getElementById('deviceName').value,
        deviceId: document.getElementById('deviceId').value,
        roomId: document.getElementById('roomId').value,
        roomCode: document.getElementById('roomCode').value
      });
    }
    
    function saveWifiSettings() {
      saveSettings({
        apName: document.getElementById('apName').value,
        apPassword: document.getElementById('apPassword').value
      });
    }
    
    function saveFirebaseSettings() {
      saveSettings({
        firebaseApiKey: document.getElementById('firebaseApiKey').value,
        firebaseAuthDomain: document.getElementById('firebaseAuthDomain').value,
        firebaseDatabaseURL: document.getElementById('firebaseDatabaseURL').value,
        firebaseProjectId: document.getElementById('firebaseProjectId').value,
        firebaseStorageBucket: document.getElementById('firebaseStorageBucket').value,
        firebaseMessagingSenderId: document.getElementById('firebaseMessagingSenderId').value,
        firebaseAppId: document.getElementById('firebaseAppId').value,
        firebaseEmail: document.getElementById('firebaseEmail').value,
        firebasePassword: document.getElementById('firebasePassword').value
      });
    }
    
    function saveHardwareSettings() {
      saveSettings({
        rgbLedPin: parseInt(document.getElementById('rgbLedPin').value) || 0,
        buzzerPin: parseInt(document.getElementById('buzzerPin').value) || 0,
        statusLedPin: parseInt(document.getElementById('statusLedPin').value) || 0,
        networkLedPin: parseInt(document.getElementById('networkLedPin').value) || 0,
        externalLedEnabled: document.getElementById('externalLedEnabled').checked
      });
    }
    
    async function saveRelayConfiguration() {
      const relays = {};
      
      document.querySelectorAll('.relay-item').forEach(card => {
        const id = parseInt(card.querySelector('.relay-id').value);
        const name = card.querySelector('.relay-name').value;
        const pinValue = card.querySelector('.relay-pin').value;
        const pin = pinValue === '' ? -1 : parseInt(pinValue, 10);
        const activeLow = card.querySelector('.relay-active-low').checked;
        const enabled = card.querySelector('.relay-enabled').checked;
        const isPulse = card.querySelector('.relay-is-pulse').checked;
        const pulseDurationMs = parseInt(card.querySelector('.relay-pulse-duration').value) || 0;
        const pulseMs = pulseDurationMs;
        const state = card.querySelector('.relay-state')?.value === '1';
        
        relays[`relay${id}`] = {
          id,
          name,
          pin,
          activeLow,
          enabled,
          isPulse,
          pulseMs,
          pulseDurationMs,
          state,
        };
      });
      
      try {
        const response = await fetch('/api/save-relays', {
          method: 'POST',
          body: JSON.stringify({ relays }),
          headers: { 'Content-Type': 'application/json' }
        });
        if (response.ok) {
          alert('Relay configuration saved successfully!');
        } else {
          alert('Failed to save relay configuration.');
        }
      } catch (err) {
        alert('Error saving relays: ' + err);
      }
    }
    
    async function restartDevice() {
      if (confirm('Are you sure you want to restart the ESP32?')) {
        try {
          await fetch('/restart', { method: 'POST' });
          alert('System rebooting, please wait...');
        } catch (err) {
          console.error(err);
        }
      }
    }
    
    window.onload = loadConfig;
  </script>
</body>
</html>
)raw";
}

String CaptivePortal::getJsonStatus() {
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  
  if (runtimeState) {
    doc["ethernetPlugged"] = runtimeState->isEthernetPlugged;
    doc["internetAvailable"] = runtimeState->internetAvailable;
    doc["firebaseReady"] = runtimeState->firebaseReady;
    doc["localIp"] = runtimeState->localIp.c_str();
    doc["networkStatus"] = (int)runtimeState->netStatus;
    doc["firebaseStatus"] = (int)runtimeState->fbStatus;
    
    // Heartbeat diagnostics for web portal API
    doc["ethernetLinked"] = runtimeState->isEthernetPlugged;
    doc["ethernetGotIp"] = (runtimeState->localIp.length() > 0);
    doc["internetOk"] = runtimeState->internetAvailable;
    doc["firebaseAuthenticated"] = runtimeState->firebaseReady;
    doc["lastSeenAt"] = millis();
    doc["heartbeatAt"] = millis();
    doc["uptimeMs"] = millis();
    
    JsonObject relaysObj = doc.createNestedObject("relays");
    for (const auto& state : runtimeState->relayStates) {
      String key = "relay" + String(state.relayId);
      JsonObject r = relaysObj.createNestedObject(key);
      const RelayConfig* cfg = relayManager->getRelayConfig(state.relayId);
      RelayConfig fallback = makeRelaySlot(state.relayId);
      if (cfg) {
        writeRelaySchema(r, *cfg);
      } else {
        writeRelaySchema(r, fallback);
      }
      r["state"] = state.isOn;
      r["isOn"] = state.isOn;
      r["lastCommand"] = state.lastCommand.c_str();
    }
  }
  
  String output;
  serializeJson(doc, output);
  return output;
}

bool CaptivePortal::validateLogin(const String& email, const String& password) {
  // Trim whitespace from inputs
  String trimmedEmail = email;
  String trimmedPassword = password;
  
  trimmedEmail.trim();
  trimmedPassword.trim();
  
  Serial.printf("[PORTAL] Login attempt - Email: '%s' (len=%d)\n", trimmedEmail.c_str(), trimmedEmail.length());
  if (trimmedPassword.length() > 0) {
    Serial.printf("[PORTAL] Login attempt - Password length: %d\n", trimmedPassword.length());
  } else {
    Serial.println("[PORTAL] Login attempt - Password: <empty>");
  }
  
  // 1. Fallback credentials (always works, solves circular NVS configuration block)
  if (trimmedEmail == "admin@hashpc.local" && trimmedPassword == "admin1234") {
    Serial.println("[PORTAL] SUCCESS - Fallback local admin login");
    return true;
  }

  // 2. Configured credentials check (local validation from saved NVS config)
  if (appConfig && 
      !appConfig->firebase.email.isEmpty() && 
      !appConfig->firebase.email.startsWith("PUT_YOUR")) {
    // Use string comparison that's more robust
    if (String(appConfig->firebase.email.c_str()).equals(trimmedEmail) && 
        String(appConfig->firebase.password.c_str()).equals(trimmedPassword)) {
      Serial.println("[PORTAL] SUCCESS - Local NVS credentials validated");
      return true;
    } else {
      Serial.printf("[PORTAL] Mismatch - Expected email: '%s', Got: '%s'\n", 
                    appConfig->firebase.email.c_str(), trimmedEmail.c_str());
    }
  }

  // 3. Online Firebase authentication check (if internet is up & API key configured)
  if (appConfig && firebaseClient && 
      !appConfig->firebase.apiKey.isEmpty() && 
      !appConfig->firebase.apiKey.startsWith("PUT_YOUR")) {
    Serial.println("[PORTAL] Attempting Firebase online authentication...");
    if (firebaseClient->signInWithPassword(appConfig->firebase.apiKey.c_str(), trimmedEmail.c_str(), trimmedPassword.c_str())) {
      Serial.println("[PORTAL] SUCCESS - Firebase authentication succeeded");
      // Update local configuration with these validated credentials
      appConfig->firebase.email = trimmedEmail.c_str();
      appConfig->firebase.password = trimmedPassword.c_str();
      saveConfigToNvs();
      return true;
    } else {
      Serial.printf("[PORTAL] Firebase auth failed: %s\n", firebaseClient->lastError().c_str());
    }
  } else {
    if (appConfig && appConfig->firebase.apiKey.isEmpty()) {
      Serial.println("[PORTAL] Cannot attempt Firebase auth - API key not configured");
    }
  }

  Serial.println("[PORTAL] FAILED - All authentication methods exhausted");
  return false;
}

void CaptivePortal::saveConfigToNvs() {
  Preferences prefs;
  if (!prefs.begin(NVS_NAMESPACE, false)) {
    Serial.println("[PORTAL] Failed to open NVS for writing");
    return;
  }
  
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  
  // Network config
  doc["deviceName"] = appConfig->network.deviceName.c_str();
  doc["deviceId"] = appConfig->network.deviceId.c_str();
  doc["roomId"] = appConfig->network.roomId.c_str();
  doc["roomCode"] = appConfig->network.roomCode.c_str();
  doc["apName"] = appConfig->network.apName.c_str();
  doc["apPassword"] = appConfig->network.apPassword.c_str();
  doc["externalLedEnabled"] = appConfig->network.externalLedEnabled;
  doc["rgbLedPin"] = appConfig->network.rgbLedPin;
  doc["statusLedPin"] = appConfig->network.statusLedPin;
  doc["networkLedPin"] = appConfig->network.networkLedPin;
  doc["buzzerPin"] = appConfig->network.buzzerPin;
  
  // Firebase config
  doc["firebaseApiKey"] = appConfig->firebase.apiKey.c_str();
  doc["firebaseAuthDomain"] = appConfig->firebase.authDomain.c_str();
  doc["firebaseDatabaseURL"] = appConfig->firebase.databaseURL.c_str();
  doc["firebaseProjectId"] = appConfig->firebase.projectId.c_str();
  doc["firebaseStorageBucket"] = appConfig->firebase.storageBucket.c_str();
  doc["firebaseMessagingSenderId"] = appConfig->firebase.messagingSenderId.c_str();
  doc["firebaseAppId"] = appConfig->firebase.appId.c_str();
  doc["firebaseEmail"] = appConfig->firebase.email.c_str();
  doc["firebasePassword"] = appConfig->firebase.password.c_str();
  
  // Relays
  doc["relayCount"] = appConfig->relayCount;
  JsonObject relaysObj = doc.createNestedObject("relays");
  for (const auto& relay : appConfig->relays) {
    JsonObject r = relaysObj.createNestedObject("relay" + String(relay.id));
    writeRelaySchema(r, relay);
  }
  
  String jsonStr;
  serializeJson(doc, jsonStr);
  
  prefs.putString(NVS_CONFIG_KEY, jsonStr);
  prefs.end();
  
  appConfig->lastSavedTime = millis();
  Serial.println("[PORTAL] Configuration saved to NVS");
}

void CaptivePortal::loadConfigFromNvs() {
  Preferences prefs;
  if (!prefs.begin(NVS_NAMESPACE, true)) {
    Serial.println("[PORTAL] Failed to open NVS for reading");
    return;
  }
  
  String jsonStr = prefs.getString(NVS_CONFIG_KEY, "");
  prefs.end();
  
  if (jsonStr.length() > 0) {
    DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
    if (deserializeJson(doc, jsonStr) == DeserializationError::Ok) {
      // Load Network Config
      if (doc.containsKey("deviceName")) appConfig->network.deviceName = doc["deviceName"].as<String>().c_str();
      if (doc.containsKey("deviceId")) appConfig->network.deviceId = doc["deviceId"].as<String>().c_str();
      if (doc.containsKey("roomId")) appConfig->network.roomId = doc["roomId"].as<String>().c_str();
      if (doc.containsKey("roomCode")) appConfig->network.roomCode = doc["roomCode"].as<String>().c_str();
      if (doc.containsKey("apName")) appConfig->network.apName = doc["apName"].as<String>().c_str();
      if (doc.containsKey("apPassword")) appConfig->network.apPassword = doc["apPassword"].as<String>().c_str();
      if (doc.containsKey("externalLedEnabled")) appConfig->network.externalLedEnabled = doc["externalLedEnabled"].as<bool>();
      if (doc.containsKey("rgbLedPin")) appConfig->network.rgbLedPin = doc["rgbLedPin"].as<uint8_t>();
      if (doc.containsKey("statusLedPin")) appConfig->network.statusLedPin = doc["statusLedPin"].as<uint8_t>();
      if (doc.containsKey("networkLedPin")) appConfig->network.networkLedPin = doc["networkLedPin"].as<uint8_t>();
      if (doc.containsKey("buzzerPin")) appConfig->network.buzzerPin = doc["buzzerPin"].as<uint8_t>();
      
      // Load Firebase Config
      if (doc.containsKey("firebaseApiKey")) appConfig->firebase.apiKey = doc["firebaseApiKey"].as<String>().c_str();
      if (doc.containsKey("firebaseAuthDomain")) appConfig->firebase.authDomain = doc["firebaseAuthDomain"].as<String>().c_str();
      if (doc.containsKey("firebaseDatabaseURL")) appConfig->firebase.databaseURL = doc["firebaseDatabaseURL"].as<String>().c_str();
      if (doc.containsKey("firebaseProjectId")) appConfig->firebase.projectId = doc["firebaseProjectId"].as<String>().c_str();
      if (doc.containsKey("firebaseStorageBucket")) appConfig->firebase.storageBucket = doc["firebaseStorageBucket"].as<String>().c_str();
      if (doc.containsKey("firebaseMessagingSenderId")) appConfig->firebase.messagingSenderId = doc["firebaseMessagingSenderId"].as<String>().c_str();
      if (doc.containsKey("firebaseAppId")) appConfig->firebase.appId = doc["firebaseAppId"].as<String>().c_str();
      if (doc.containsKey("firebaseEmail")) appConfig->firebase.email = doc["firebaseEmail"].as<String>().c_str();
      if (doc.containsKey("firebasePassword")) appConfig->firebase.password = doc["firebasePassword"].as<String>().c_str();
      
      // Load Relays
      if (doc.containsKey("relays")) {
        std::vector<RelayConfig> loadedRelays;
        JsonVariantConst relaysValue = doc["relays"];
        if (relaysValue.is<JsonArrayConst>()) {
          JsonArrayConst relayArray = relaysValue.as<JsonArrayConst>();
          uint8_t fallbackId = 1;
          for (JsonObjectConst relayObj : relayArray) {
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
          JsonObjectConst relayObjMap = relaysValue.as<JsonObjectConst>();
          for (JsonPairConst kv : relayObjMap) {
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
        appConfig->relays = normalizeRelaySlots(loadedRelays);
        appConfig->relayCount = MAX_RELAYS;
      }
      
      normalizeRelayConfiguration(*appConfig);
      
      Serial.println("[PORTAL] Full Configuration loaded from NVS");
    }
  }
}
