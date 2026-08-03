#ifndef CAPTIVE_PORTAL_H
#define CAPTIVE_PORTAL_H

#include <DNSServer.h>
#include <WebServer.h>
#include <WiFi.h>
#include "pc_types.h"
#include "config.h"
#include "relay_manager.h"
#include "firebase_client.h"

class CaptivePortal {
 public:
  CaptivePortal();
  void initialize(AppConfig* config, RuntimeState* state, RelayManager* relayMgr, FirebaseClient* fbClient);
  void start();
  void stop();
  void update();
  
  bool getIsAuthenticated() const { return isAuthenticated; }

 private:
  WebServer webServer;
  DNSServer dnsServer;
  String apName;
  String apPassword;
  
  AppConfig* appConfig = nullptr;
  RuntimeState* runtimeState = nullptr;
  RelayManager* relayManager = nullptr;
  FirebaseClient* firebaseClient = nullptr;
  
  bool isRunning;
  bool isAuthenticated;
  String authToken;
  
  void setupRoutes();
  void handleNotFound();
  void handleRoot();
  void handleLogin();
  void handleDashboard();
  void handleSettings();
  void handleSaveSettings();
  void handleSaveRelays();
  void handleRestart();
  void handleLogout();
  void handleApi();
  void handleControlRelay();
  
  String getLoginHtml();
  String getDashboardHtml();
  String getSettingsHtml();
  String getJsonStatus();
  
  bool validateLogin(const String& email, const String& password);
  void saveConfigToNvs();
  void loadConfigFromNvs();
};

#endif // CAPTIVE_PORTAL_H
