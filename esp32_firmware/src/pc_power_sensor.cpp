#include "pc_power_sensor.h"

PcPowerSensor::PcPowerSensor(uint8_t pin, bool activeHigh, uint32_t debounceMs)
  : pin(pin), activeHigh(activeHigh), debounceMs(debounceMs) {
}

void PcPowerSensor::initialize() {
  pinMode(pin, INPUT);  // input only — never drives the PLED line
  bool raw = readRaw();
  debouncedState = raw;
  candidateState = raw;
  candidateSinceMs = millis();
  sampleCount = 1;
  Serial.printf("[PC-SENSE] GPIO%d initialized, initial state: %s\n", pin, debouncedState ? "ON" : "OFF");
}

bool PcPowerSensor::readRaw() const {
  int level = digitalRead(pin);
  bool high = (level == HIGH);
  return activeHigh ? high : !high;
}

void PcPowerSensor::update() {
  uint32_t now = millis();
  // Sample every 20ms — plenty fast for a debounce window measured in
  // hundreds of ms, and cheap enough to call unconditionally from loop().
  if (now - lastSampleMs < 20) {
    return;
  }
  lastSampleMs = now;
  sampleCount++;

  bool raw = readRaw();

  if (raw != candidateState) {
    // Signal moved — restart the debounce window instead of accepting the
    // change immediately. This is what filters out brief electrical noise.
    candidateState = raw;
    candidateSinceMs = now;
    return;
  }

  if (candidateState != debouncedState && (now - candidateSinceMs) >= debounceMs) {
    debouncedState = candidateState;
    Serial.printf("[PC-SENSE] Confirmed PC actual state: %s\n", debouncedState ? "ON" : "OFF");
  }
}
