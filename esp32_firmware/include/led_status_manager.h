#ifndef LED_STATUS_MANAGER_H
#define LED_STATUS_MANAGER_H

#include <Adafruit_NeoPixel.h>
#include "pc_types.h"

class LedStatusManager {
 public:
  LedStatusManager(uint8_t rgbPin, uint8_t statusPin, uint8_t networkPin, uint8_t buzzerPin, bool enableExternal);
  void initialize();
  void updateStatus(NetworkStatus netStatus, FirebaseStatus fbStatus);
  void update();
  void triggerBlinkFeedback(); // Brief visual flash on commands

  void setBuzzerOn(bool on);           // Direct buzzer control for ALERT hold
  void startInternetLossAlert();       // Start 5-minute beep pattern
  void stopInternetLossAlert();        // Stop internet loss alert
  bool isInternetLossAlertActive() const; // Check if alert is running

  // Helper static colors
  static const uint32_t COLOR_BLUE;
  static const uint32_t COLOR_ORANGE;
  static const uint32_t COLOR_GREEN;
  static const uint32_t COLOR_RED;
  static const uint32_t COLOR_OFF;

 private:
  Adafruit_NeoPixel rgbLed;
  uint8_t statusLedPin;
  uint8_t networkLedPin;
  uint8_t buzzerPin;
  bool externalLedEnabled;
  
  NetworkStatus currentStatus;
  FirebaseStatus fbStatus;
  bool blinkState;
  uint32_t lastBlinkTime;
  uint32_t feedbackEndTime = 0; // Timestamp when command flash ends
  uint32_t buzzerFeedbackEndTime = 0;
  
  bool buzzerManualOn = false;           // ALERT hold state
  bool internetLossAlertActive = false;  // Internet loss beeping
  bool alertPatternState = false;        // Alternating alert tone state
  uint32_t internetLossAlertStart = 0;   // When internet loss alert started
  uint32_t lastInternetLossBeep = 0;     // Last beep time for pattern
  uint32_t lastAlertPatternTime = 0;     // Last alert pattern toggle time
  static constexpr uint32_t INTERNET_LOSS_ALERT_DURATION_MS = 300000; // 5 minutes
  
  void updateLedStates();
  void setRgbColor(uint32_t color);
  void setStatusLed(bool state);
  void setNetworkLed(bool state);
};

#endif // LED_STATUS_MANAGER_H
