#ifndef CONFIG_H
#define CONFIG_H

#include "pc_types.h"

#if __has_include("generated_env.h")
#include "generated_env.h"
#endif

// ===================== HARDWARE PINS =====================
#define RELAY_1_PIN 21
#define RELAY_2_PIN 17
#define RELAY_3_PIN 16
#define RELAY_4_PIN 18
#define RELAY_5_PIN 15
#define RELAY_6_PIN 3
#define RELAY_7_PIN 2
#define RELAY_8_PIN 1
#define RELAY_9_PIN 0
#define RELAY_10_PIN 44
#define BUZZER_PIN 43
#define STATUS_LED_PIN 47
#define NETWORK_LED_PIN 48
#define RGB_LED_PIN 46

// Ethernet W5500 SPI Pins
#define ETH_MISO_PIN 12
#define ETH_MOSI_PIN 11
#define ETH_SCLK_PIN 13
#define ETH_CS_PIN 14
#define ETH_IRQ_PIN 10
#define ETH_RST_PIN 9

// ===================== WIFI AP DEFAULTS =====================
#define DEFAULT_AP_NAME "PC-Control-Setup"
#define DEFAULT_AP_PASSWORD "12345678"

// ===================== FIREBASE CREDENTIALS =====================
#ifndef FB_API_KEY
#define FB_API_KEY "PUT_YOUR_FIREBASE_API_KEY_HERE"
#endif
#ifndef FB_AUTH_DOMAIN
#define FB_AUTH_DOMAIN "PUT_YOUR_FIREBASE_AUTH_DOMAIN_HERE"
#endif
#ifndef FB_DATABASE_URL
#define FB_DATABASE_URL "PUT_YOUR_FIREBASE_DATABASE_URL_HERE"
#endif
#ifndef FB_PROJECT_ID
#define FB_PROJECT_ID "PUT_YOUR_FIREBASE_PROJECT_ID_HERE"
#endif
#ifndef FB_STORAGE_BUCKET
#define FB_STORAGE_BUCKET "PUT_YOUR_FIREBASE_STORAGE_BUCKET_HERE"
#endif
#ifndef FB_MESSAGING_SENDER_ID
#define FB_MESSAGING_SENDER_ID "PUT_YOUR_FIREBASE_MESSAGING_SENDER_ID_HERE"
#endif
#ifndef FB_APP_ID
#define FB_APP_ID "PUT_YOUR_FIREBASE_APP_ID_HERE"
#endif
#ifndef FB_EMAIL
#define FB_EMAIL "PUT_YOUR_FIREBASE_EMAIL_HERE"
#endif
#ifndef FB_PASSWORD
#define FB_PASSWORD "PUT_YOUR_FIREBASE_PASSWORD_HERE"
#endif

// ===================== NVS STORAGE =====================
#define NVS_NAMESPACE "pcctrl"
#define NVS_CONFIG_KEY "config"

// ===================== NETWORK TIMEOUTS =====================
#define ETH_CONNECT_TIMEOUT_MS 10000
#define INTERNET_CHECK_INTERVAL_MS 30000
#define FIREBASE_RECONNECT_INTERVAL_MS 3000
#define NETWORK_STATUS_UPDATE_INTERVAL_MS 5000
#define RELAY_COMMAND_DEBOUNCE_MS 500

// ===================== MEMORY & STORAGE =====================
#define MAX_JSON_DOC_SIZE 4096
#define SERIAL_BAUD_RATE 115200
#define WEB_SERVER_PORT 80

// ===================== DEFAULT APP CONFIG =====================
inline AppConfig getDefaultConfig() {
  AppConfig config;
  
  // Network
  config.network.deviceName = "PC Control Hub";
  config.network.deviceId = ""; // Assigned dynamically during setup
  config.network.roomId = "default";
  config.network.roomCode = "main";
  config.network.apName = DEFAULT_AP_NAME;
  config.network.apPassword = DEFAULT_AP_PASSWORD;
  config.network.externalLedEnabled = true;
  config.network.rgbLedPin = RGB_LED_PIN;
  config.network.statusLedPin = STATUS_LED_PIN;
  config.network.networkLedPin = NETWORK_LED_PIN;
  config.network.buzzerPin = BUZZER_PIN;
  
  // Firebase
  config.firebase.apiKey = FB_API_KEY;
  config.firebase.authDomain = FB_AUTH_DOMAIN;
  config.firebase.databaseURL = FB_DATABASE_URL;
  config.firebase.projectId = FB_PROJECT_ID;
  config.firebase.storageBucket = FB_STORAGE_BUCKET;
  config.firebase.messagingSenderId = FB_MESSAGING_SENDER_ID;
  config.firebase.appId = FB_APP_ID;
  config.firebase.email = FB_EMAIL;
  config.firebase.password = FB_PASSWORD;
  
  // Relays - full 10-relay layout with persistent slots
  config.relays = makeDefaultRelaySlots();
  config.relayCount = MAX_RELAYS;
  
  return config;
}

#endif // CONFIG_H
