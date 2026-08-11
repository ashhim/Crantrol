#ifndef PC_POWER_SENSOR_H
#define PC_POWER_SENSOR_H

#include <Arduino.h>

// Reads the motherboard front-panel PLED signal and reports a debounced,
// authoritative PC ON/OFF state. This is intentionally independent of
// Relay 1 — Relay 1 only controls the PSU feed; it does not by itself
// confirm the PC actually powered on. GPIO is configured INPUT only, the
// firmware never drives this pin.
class PcPowerSensor {
 public:
  explicit PcPowerSensor(uint8_t pin, bool activeHigh, uint32_t debounceMs);

  void initialize();
  // Call frequently from loop(); internally rate-limited to a light sample
  // cadence so it costs nothing extra.
  void update();

  // Debounced, authoritative PC state.
  bool isOn() const { return debouncedState; }

  // True once at least one debounce window has completed since boot, so
  // callers can distinguish "confirmed OFF" from "not sampled yet".
  bool hasStableReading() const { return sampleCount > 0; }

 private:
  uint8_t pin;
  bool activeHigh;
  uint32_t debounceMs;

  bool debouncedState = false;
  bool candidateState = false;
  uint32_t candidateSinceMs = 0;
  uint32_t lastSampleMs = 0;
  uint32_t sampleCount = 0;

  bool readRaw() const;
};

#endif  // PC_POWER_SENSOR_H
