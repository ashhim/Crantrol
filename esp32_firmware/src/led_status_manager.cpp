#include "led_status_manager.h"

// Static color definitions
const uint32_t LedStatusManager::COLOR_BLUE   = Adafruit_NeoPixel::Color(0, 0, 255);
const uint32_t LedStatusManager::COLOR_ORANGE = Adafruit_NeoPixel::Color(255, 120, 0);
const uint32_t LedStatusManager::COLOR_GREEN  = Adafruit_NeoPixel::Color(0, 255, 0);
const uint32_t LedStatusManager::COLOR_RED    = Adafruit_NeoPixel::Color(255, 0, 0);
const uint32_t LedStatusManager::COLOR_OFF    = Adafruit_NeoPixel::Color(0, 0, 0);

LedStatusManager::LedStatusManager(uint8_t rgbPin, uint8_t statusPin, uint8_t networkPin, uint8_t buzzerPin, bool enableExternal)
  : rgbLed(1, rgbPin, NEO_GRB + NEO_KHZ800),
    statusLedPin(statusPin),
    networkLedPin(networkPin),
    buzzerPin(buzzerPin),
    externalLedEnabled(enableExternal),
    currentStatus(NetworkStatus::NOT_PLUGGED),
    fbStatus(FirebaseStatus::DISCONNECTED),
    blinkState(false),
    lastBlinkTime(0) {
}

void LedStatusManager::initialize() {
  rgbLed.begin();
  rgbLed.setBrightness(50); // Set moderate brightness to avoid drawing too much current
  rgbLed.show();
  
  if (externalLedEnabled) {
    if (statusLedPin > 0) {
      pinMode(statusLedPin, OUTPUT);
      digitalWrite(statusLedPin, LOW);
    }
    if (networkLedPin > 0) {
      pinMode(networkLedPin, OUTPUT);
      digitalWrite(networkLedPin, LOW);
    }
  }

  if (buzzerPin > 0) {
    pinMode(buzzerPin, OUTPUT);
    digitalWrite(buzzerPin, LOW);
  }
}

void LedStatusManager::updateStatus(NetworkStatus netStatus, FirebaseStatus fbStatus) {
  currentStatus = netStatus;
  this->fbStatus = fbStatus;
}

void LedStatusManager::update() {
  uint32_t now = millis();
  
  // Handle blinking (1000ms interval for a 2-second cycle)
  // 1000ms ON, 1000ms OFF = 2 second total cycle
  if (now - lastBlinkTime >= 1000) {
    blinkState = !blinkState;
    lastBlinkTime = now;
  }
  
  const bool visualFeedbackActive = now < feedbackEndTime;
  const bool buzzerFeedbackActive = now < buzzerFeedbackEndTime;

  if (visualFeedbackActive) {
    // Blink NeoPixel White and turn external status LEDs HIGH for visual feedback
    setRgbColor(Adafruit_NeoPixel::Color(255, 255, 255));
    if (externalLedEnabled) {
      if (statusLedPin > 0) digitalWrite(statusLedPin, HIGH);
      if (networkLedPin > 0) digitalWrite(networkLedPin, HIGH);
    }
  } else {
    updateLedStates();
  }

  if (buzzerPin > 0) {
    if (buzzerManualOn) {
      // ALERT hold: loud industrial alarm pattern
      if (now - lastAlertPatternTime >= 120) {
        lastAlertPatternTime = now;
        alertPatternState = !alertPatternState;
      }
      tone(buzzerPin, alertPatternState ? 3200 : 2200);
    } else if (internetLossAlertActive) {
      // Internet loss: beep pattern (200ms on, 800ms off)
      uint32_t elapsed = now - lastInternetLossBeep;
      if (elapsed < 200) {
        tone(buzzerPin, 2800);
      } else if (elapsed >= 1000) {
        lastInternetLossBeep = now;
        tone(buzzerPin, 2800);
      } else {
        noTone(buzzerPin);
      }
      // Auto-stop after 5 minutes
      if (now - internetLossAlertStart > INTERNET_LOSS_ALERT_DURATION_MS) {
        internetLossAlertActive = false;
        noTone(buzzerPin);
      }
    } else if (buzzerFeedbackActive) {
      tone(buzzerPin, 2600);
    } else {
      noTone(buzzerPin);
    }
  }
}

void LedStatusManager::triggerBlinkFeedback() {
  feedbackEndTime = millis() + 250; // Visual flash for 250 milliseconds
  buzzerFeedbackEndTime = millis() + 250; // Short confirmation beep
}

void LedStatusManager::updateLedStates() {
  uint32_t rgbColor = COLOR_OFF;
  bool statusLedState = false;
  bool networkLedState = false;
  
  // 1. Determine external network led (on if ethernet is plugged)
  networkLedState = (currentStatus != NetworkStatus::NOT_PLUGGED);
  
  // 2. Determine external status led (on if connected to internet + Firebase)
  statusLedState = (currentStatus == NetworkStatus::INTERNET_READY && fbStatus == FirebaseStatus::AUTHENTICATED);
  
  // 3. Determine onboard RGB NeoPixel Color - Priority based on connection state
  if (currentStatus == NetworkStatus::NOT_PLUGGED) {
    // Solid Blue: No Ethernet cable plugged
    rgbColor = COLOR_BLUE;
  } 
  else if (currentStatus == NetworkStatus::PLUGGED_NO_IP) {
    // Solid Orange: Ethernet plugged, but no IP address acquired yet
    rgbColor = COLOR_ORANGE;
  }
  else if (currentStatus == NetworkStatus::IP_ACQUIRED) {
    // Blinking Red: IP acquired but Internet is NOT available (2-second interval: 1s Red, 1s OFF)
    rgbColor = blinkState ? COLOR_RED : COLOR_OFF;
  }
  else if (currentStatus == NetworkStatus::INTERNET_READY) {
    // Blinking Green: Internet is available (2-second interval: 1s Green, 1s OFF)
    rgbColor = blinkState ? COLOR_GREEN : COLOR_OFF;
  }
  else if (currentStatus == NetworkStatus::INTERNET_DOWN) {
    // Blinking Red: Internet was available but now down (2-second interval: 1s Red, 1s OFF)
    rgbColor = blinkState ? COLOR_RED : COLOR_OFF;
  }
  
  // Set RGB LED
  setRgbColor(rgbColor);
  
  // Set status LEDs if enabled
  if (externalLedEnabled) {
    if (statusLedPin > 0) setStatusLed(statusLedState);
    if (networkLedPin > 0) setNetworkLed(networkLedState);
  }
}

void LedStatusManager::setRgbColor(uint32_t color) {
  rgbLed.setPixelColor(0, color);
  rgbLed.show();
}

void LedStatusManager::setStatusLed(bool state) {
  digitalWrite(statusLedPin, state ? HIGH : LOW);
}

void LedStatusManager::setNetworkLed(bool state) {
  digitalWrite(networkLedPin, state ? HIGH : LOW);
}

void LedStatusManager::setBuzzerOn(bool on) {
  buzzerManualOn = on;
  if (!on && buzzerPin > 0) {
    noTone(buzzerPin);
  }
}

void LedStatusManager::startInternetLossAlert() {
  if (!internetLossAlertActive) {
    internetLossAlertActive = true;
    internetLossAlertStart = millis();
    lastInternetLossBeep = millis();
    Serial.println("[BUZZER] Internet loss alert started (5 min)");
  }
}

void LedStatusManager::stopInternetLossAlert() {
  if (internetLossAlertActive) {
    internetLossAlertActive = false;
    if (buzzerPin > 0) {
      noTone(buzzerPin);
    }
    Serial.println("[BUZZER] Internet loss alert stopped");
  }
}

bool LedStatusManager::isInternetLossAlertActive() const {
  return internetLossAlertActive;
}
