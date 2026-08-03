#ifndef FIREBASE_CLIENT_H
#define FIREBASE_CLIENT_H

#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "pc_types.h"
#include "config.h"

class FirebaseClient {
 public:
  FirebaseClient();
  void initialize(const FirebaseConfig& config, const String& deviceId, const String& deviceName = "");
  void update();
  void setRuntimeState(RuntimeState* state) { runtimeState = state; }
  
  bool authenticate();
  bool refreshToken();
  FirebaseStatus getStatus() const { return status; }
  
  bool readDesiredCommands(std::vector<FirebaseCommand>& commands);
  bool writeStatus(const RuntimeState& state, const AppConfig& config);
  bool writeRelayStates(const std::vector<RelayState>& states);
  bool writeDeviceConfig(const AppConfig& config);
  bool writeLogs(const String& message);
  bool clearDesiredCommands();

  // Authentication utility
  bool signInWithPassword(const String& apiKey, const String& email, const String& password);
  String lastError() const { return lastErrorStr; }

 private:
  FirebaseConfig firebaseConfig;
  FirebaseStatus status;
  String authToken;
  String refreshTokenStr;
  uint32_t tokenExpireTime;
  uint32_t lastTokenRefresh;
  String deviceId;
  String deviceName;
  RuntimeState* runtimeState = nullptr;
  String lastErrorStr;
  
  String getAuthUrl(const String& apiKey);
  String getDatabaseUrl(const String& dbUrl, const String& path);
  bool makeAuthRequest(const String& url, const String& payload, String& response);
  bool makeGetRequest(const String& url, String& response);
  bool makePostRequest(const String& url, const String& payload, String& response);
  bool makePutRequest(const String& url, const String& payload, String& response);
  bool makeDeleteRequest(const String& url, String& response);
  bool makePatchRequest(const String& url, const String& payload, String& response);
  
  void printHttpError(int httpCode);
  bool parseCommand(const String& json, FirebaseCommand& cmd);
};

#endif // FIREBASE_CLIENT_H
