#include "firebase_client.h"

static String urlEncode(const String& s) {
  String out;
  char buf[4];
  for (size_t i = 0; i < s.length(); ++i) {
    char c = s[i];
    if (isalnum(static_cast<unsigned char>(c)) || c == '-' || c == '_' || c == '.' || c == '~') {
      out += c;
    } else {
      snprintf(buf, sizeof(buf), "%%%02X", static_cast<unsigned char>(c));
      out += buf;
    }
  }
  return out;
}

FirebaseClient::FirebaseClient()
  : status(FirebaseStatus::DISCONNECTED),
    tokenExpireTime(0),
    lastTokenRefresh(0) {
}

void FirebaseClient::initialize(const FirebaseConfig& config, const String& deviceId, const String& deviceName) {
  firebaseConfig = config;
  this->deviceId = deviceId;
  this->deviceName = deviceName;
  Serial.println("[FB] Firebase client initialized");
}

void FirebaseClient::update() {
  // Check if token needs refresh
  if (status == FirebaseStatus::AUTHENTICATED) {
    if (millis() > tokenExpireTime - 300000) {  // Refresh 5 minutes before expiry
      if (!refreshToken()) {
        status = FirebaseStatus::AUTH_FAILED;
      }
    }
  }
}

String FirebaseClient::getAuthUrl(const String& apiKey) {
  return "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + apiKey;
}

String FirebaseClient::getDatabaseUrl(const String& dbUrl, const String& path) {
  String baseUrl = dbUrl;
  if (baseUrl.endsWith("/")) {
    baseUrl.remove(baseUrl.length() - 1);
  }
  return baseUrl + path + ".json?auth=" + urlEncode(authToken);
}

bool FirebaseClient::signInWithPassword(const String& apiKey, const String& email, const String& password) {
  status = FirebaseStatus::AUTHENTICATING;
  lastErrorStr.clear();
  
  DynamicJsonDocument doc(256);
  doc["email"] = email;
  doc["password"] = password;
  doc["returnSecureToken"] = true;
  
  String payload;
  serializeJson(doc, payload);
  
  String url = getAuthUrl(apiKey);
  String response;
  if (!makeAuthRequest(url, payload, response)) {
    Serial.println("[FB] Sign-in request failed");
    status = FirebaseStatus::AUTH_FAILED;
    return false;
  }
  
  // Parse response
  DynamicJsonDocument respDoc(1536);
  if (deserializeJson(respDoc, response) != DeserializationError::Ok) {
    Serial.println("[FB] Failed to parse auth response");
    lastErrorStr = "JSON parse failed";
    status = FirebaseStatus::AUTH_FAILED;
    return false;
  }
  
  if (respDoc.containsKey("idToken")) {
    authToken = respDoc["idToken"].as<String>();
    refreshTokenStr = respDoc["refreshToken"].as<String>();
    uint32_t expiresIn = respDoc["expiresIn"] | 3600;
    tokenExpireTime = millis() + (expiresIn * 1000);
    status = FirebaseStatus::AUTHENTICATED;
    lastTokenRefresh = millis();
    Serial.println("[FB] Authentication successful");
    return true;
  } else {
    if (respDoc.containsKey("error")) {
      lastErrorStr = respDoc["error"]["message"].as<String>();
      Serial.printf("[FB] Auth error: %s\n", lastErrorStr.c_str());
    } else {
      lastErrorStr = "Unknown auth failure";
    }
    status = FirebaseStatus::AUTH_FAILED;
    return false;
  }
}

bool FirebaseClient::authenticate() {
  if (firebaseConfig.apiKey.isEmpty() || firebaseConfig.apiKey.startsWith("PUT_YOUR")) {
    lastErrorStr = "Firebase API key not configured";
    status = FirebaseStatus::AUTH_FAILED;
    return false;
  }
  return signInWithPassword(firebaseConfig.apiKey, firebaseConfig.email, firebaseConfig.password);
}

bool FirebaseClient::refreshToken() {
  if (refreshTokenStr.isEmpty()) {
    lastErrorStr = "No refresh token available";
    return false;
  }
  
  String url = "https://securetoken.googleapis.com/v1/token?key=" + firebaseConfig.apiKey;
  String payload = "grant_type=refresh_token&refresh_token=" + urlEncode(refreshTokenStr);
  
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);
  
  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) {
    lastErrorStr = "Token refresh http begin failed";
    return false;
  }
  
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");
  int httpCode = http.POST(payload);
  
  String response;
  if (httpCode > 0) {
    response = http.getString();
  }
  http.end();
  
  if (httpCode < 200 || httpCode >= 300) {
    lastErrorStr = "Token refresh rejected: " + String(httpCode);
    return false;
  }
  
  DynamicJsonDocument doc(1024);
  if (deserializeJson(doc, response) != DeserializationError::Ok) {
    lastErrorStr = "Failed to parse token refresh JSON";
    return false;
  }
  
  authToken = doc["id_token"].as<String>();
  refreshTokenStr = doc["refresh_token"].as<String>();
  uint32_t expiresIn = doc["expires_in"] | 3600;
  tokenExpireTime = millis() + (expiresIn * 1000);
  lastTokenRefresh = millis();
  return true;
}

bool FirebaseClient::readDesiredCommands(std::vector<FirebaseCommand>& commands) {
  if (status != FirebaseStatus::AUTHENTICATED) {
    return false;
  }
  
  String path = "/devices/" + deviceId + "/desired";
  String url = getDatabaseUrl(firebaseConfig.databaseURL, path);
  
  String response;
  if (!makeGetRequest(url, response)) {
    return false;
  }
  
  if (response == "null" || response.length() == 0) {
    return true;
  }
  
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  if (deserializeJson(doc, response) != DeserializationError::Ok) {
    return false;
  }
  
  commands.clear();
  
  // Parse either JSON Object map of relay commands or JSON Array
  if (doc.is<JsonObject>()) {
    JsonObject root = doc.as<JsonObject>();
    for (JsonPair kv : root) {
      if (kv.value().is<JsonObject>()) {
        JsonObject cmdObj = kv.value().as<JsonObject>();
        FirebaseCommand cmd;
        cmd.relayId = kv.key().c_str();
        cmd.command = cmdObj["command"] | "";
        cmd.timestamp = cmdObj["timestamp"] | 0;
        cmd.revision = cmdObj["revision"] | "";
        
        if (!cmd.command.isEmpty() && !cmd.revision.isEmpty()) {
          commands.push_back(cmd);
        }
      }
    }
  }
  
  return true;
}

bool FirebaseClient::writeStatus(const RuntimeState& state, const AppConfig& config) {
  if (status != FirebaseStatus::AUTHENTICATED) {
    return false;
  }
  
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  doc["ethernetLinked"] = state.isEthernetPlugged;
  doc["ethernetGotIp"] = (state.localIp.length() > 0);
  doc["internetOk"] = state.internetAvailable;
  doc["firebaseAuthenticated"] = state.firebaseReady;
  doc["uptimeMs"] = millis();

  // Authoritative PC power state from the PLED sense input (GPIO45) —
  // debounced in firmware, never derived from Relay 1.
  doc["pcActualOn"] = state.pcActualOn;
  doc["pcActualStable"] = state.pcActualStable;
  doc["deviceName"] = deviceName.c_str();
  doc["deviceId"] = deviceId.c_str();
  
  // Firebase server timestamps
  JsonObject lastSeen = doc.createNestedObject("lastSeenAt");
  lastSeen[".sv"] = "timestamp";
  JsonObject heartbeat = doc.createNestedObject("heartbeatAt");
  heartbeat[".sv"] = "timestamp";
  
  // Relays as Map/Object (key: relay1, relay2...)
  JsonObject relaysObj = doc.createNestedObject("relays");
  for (const auto& relay : config.relays) {
    String key = "relay" + String(relay.id);
    JsonObject r = relaysObj.createNestedObject(key);
    writeRelaySchema(r, relay);
    
    bool isOn = false;
    for (const auto& rs : state.relayStates) {
      if (rs.relayId == relay.id) {
        isOn = rs.isOn;
        break;
      }
    }
    r["state"] = isOn;
  }
  
  String payload;
  serializeJson(doc, payload);
  
  String path = "/devices/" + deviceId + "/status";
  String url = getDatabaseUrl(firebaseConfig.databaseURL, path);
  
  String response;
  return makePutRequest(url, payload, response);
}

bool FirebaseClient::writeRelayStates(const std::vector<RelayState>& states) {
  if (status != FirebaseStatus::AUTHENTICATED) {
    return false;
  }
  
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  JsonObject relaysObj = doc.createNestedObject("relays");
  
  for (uint8_t relayId = 1; relayId <= MAX_RELAYS; ++relayId) {
    const RelayState* matchedState = nullptr;
    for (const auto& state : states) {
      if (state.relayId == relayId) {
        matchedState = &state;
        break;
      }
    }
    
    JsonObject r = relaysObj.createNestedObject("relay" + String(relayId));
    writeRelaySchema(r, makeRelaySlot(relayId));
    
    const bool isOn = matchedState ? matchedState->isOn : false;
    r["state"] = isOn;
    r["isOn"] = isOn;
    if (matchedState) {
      r["lastCommand"] = matchedState->lastCommand.c_str();
      r["commandRevision"] = matchedState->commandRevision.c_str();
    } else {
      r["lastCommand"] = "OFF";
      r["commandRevision"] = "";
    }
  }
  
  String payload;
  serializeJson(doc, payload);
  
  String path = "/devices/" + deviceId + "/status/relays";
  String url = getDatabaseUrl(firebaseConfig.databaseURL, path);
  
  String response;
  return makePutRequest(url, payload, response);
}

bool FirebaseClient::writeDeviceConfig(const AppConfig& config) {
  if (status != FirebaseStatus::AUTHENTICATED) {
    return false;
  }
  
  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  doc["deviceName"] = config.network.deviceName.c_str();
  doc["deviceId"] = config.network.deviceId.c_str();
  doc["roomId"] = config.network.roomId.c_str();
  doc["roomCode"] = config.network.roomCode.c_str();
  doc["relayCount"] = config.relayCount;
  doc["timestamp"] = millis();
  
  // Relays as Map/Object (key: relay1, relay2...)
  JsonObject relaysObj = doc.createNestedObject("relays");
  for (const auto& relay : config.relays) {
    String key = "relay" + String(relay.id);
    JsonObject r = relaysObj.createNestedObject(key);
    writeRelaySchema(r, relay);
  }
  
  String payload;
  serializeJson(doc, payload);
  
  String path = "/devices/" + deviceId + "/config";
  String url = getDatabaseUrl(firebaseConfig.databaseURL, path);
  
  String response;
  return makePutRequest(url, payload, response);
}

bool FirebaseClient::writeNetworkDevices(const std::vector<DiscoveredDevice>& devices, const String& subnetCidr) {
  if (status != FirebaseStatus::AUTHENTICATED) {
    return false;
  }

  DynamicJsonDocument doc(MAX_JSON_DOC_SIZE);
  doc["subnet"] = subnetCidr;
  doc["deviceCount"] = devices.size();
  JsonObject updatedAt = doc.createNestedObject("updatedAt");
  updatedAt[".sv"] = "timestamp";

  // One consolidated write for the whole inventory — never one write per
  // host. Firebase keys can't contain '.', so IPs are stored dot-sanitized.
  JsonObject hostsObj = doc.createNestedObject("hosts");
  uint32_t now = millis();
  for (const auto& device : devices) {
    String key = device.ip.toString();
    key.replace(".", "_");

    JsonObject h = hostsObj.createNestedObject(key);
    h["ip"] = device.ip.toString();
    h["mac"] = device.mac;
    h["hostname"] = device.hostname;
    h["active"] = device.active;
    h["lastSeenAgoMs"] = (now >= device.lastSeenMs) ? (now - device.lastSeenMs) : 0;
  }

  String payload;
  serializeJson(doc, payload);

  String path = "/devices/" + deviceId + "/network";
  String url = getDatabaseUrl(firebaseConfig.databaseURL, path);

  String response;
  return makePutRequest(url, payload, response);
}

bool FirebaseClient::writeLogs(const String& message) {
  if (status != FirebaseStatus::AUTHENTICATED) {
    return false;
  }
  
  DynamicJsonDocument doc(512);
  doc["timestamp"] = millis();
  doc["message"] = message;
  
  String payload;
  serializeJson(doc, payload);
  
  String path = "/devices/" + deviceId + "/logs";
  String url = getDatabaseUrl(firebaseConfig.databaseURL, path);
  
  String response;
  return makePostRequest(url, payload, response);
}

bool FirebaseClient::clearDesiredCommands() {
  if (status != FirebaseStatus::AUTHENTICATED) {
    return false;
  }

  String path = "/devices/" + deviceId + "/desired";
  String url = getDatabaseUrl(firebaseConfig.databaseURL, path);

  String response;
  const bool ok = makeDeleteRequest(url, response);
  if (ok) {
    Serial.println("[FB] Cleared desired command queue");
  } else {
    Serial.println("[FB] Failed to clear desired command queue");
  }
  return ok;
}

bool FirebaseClient::makeAuthRequest(const String& url, const String& payload, String& response) {
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);
  
  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) {
    return false;
  }
  
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.POST(payload);
  
  if (httpCode > 0) {
    response = http.getString();
    http.end();
    return (httpCode >= 200 && httpCode < 300) || httpCode == 400;
  }
  
  printHttpError(httpCode);
  http.end();
  return false;
}

bool FirebaseClient::makeGetRequest(const String& url, String& response) {
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);
  
  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) {
    return false;
  }
  
  int httpCode = http.GET();
  if (httpCode > 0) {
    response = http.getString();
    http.end();
    return (httpCode >= 200 && httpCode < 300);
  }
  
  printHttpError(httpCode);
  http.end();
  return false;
}

bool FirebaseClient::makePostRequest(const String& url, const String& payload, String& response) {
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);
  
  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) {
    return false;
  }
  
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.POST(payload);
  if (httpCode > 0) {
    response = http.getString();
    http.end();
    return (httpCode >= 200 && httpCode < 300);
  }
  
  printHttpError(httpCode);
  http.end();
  return false;
}

bool FirebaseClient::makePutRequest(const String& url, const String& payload, String& response) {
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);
  
  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) {
    return false;
  }
  
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.PUT(payload);
  if (httpCode > 0) {
    response = http.getString();
    http.end();
    return (httpCode >= 200 && httpCode < 300);
  }
  
  printHttpError(httpCode);
  http.end();
  return false;
}

bool FirebaseClient::makeDeleteRequest(const String& url, String& response) {
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);

  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) {
    return false;
  }

  int httpCode = http.sendRequest("DELETE");
  if (httpCode > 0) {
    response = http.getString();
    http.end();
    return (httpCode >= 200 && httpCode < 300);
  }

  printHttpError(httpCode);
  http.end();
  return false;
}

bool FirebaseClient::makePatchRequest(const String& url, const String& payload, String& response) {
  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);
  
  HTTPClient http;
  http.setTimeout(10000);
  if (!http.begin(client, url)) {
    return false;
  }
  
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.sendRequest("PATCH", (uint8_t*)payload.c_str(), payload.length());
  if (httpCode > 0) {
    response = http.getString();
    http.end();
    return (httpCode >= 200 && httpCode < 300);
  }
  
  printHttpError(httpCode);
  http.end();
  return false;
}

void FirebaseClient::printHttpError(int httpCode) {
  Serial.printf("[FB] HTTP Error Code: %d\n", httpCode);
}
