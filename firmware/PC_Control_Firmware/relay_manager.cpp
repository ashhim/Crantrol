#include "relay_manager.h"

RelayManager::RelayManager() {
  for (uint8_t i = 0; i < MAX_RELAYS; i++) {
    relayStates[i] = false;
    pulseOffTimeMs[i] = 0;
    lastRevisions[i] = "";
  }
}

void RelayManager::initializeRelays(const std::vector<RelayConfig>& configs) {
  relayConfigs = normalizeRelaySlots(configs);
  
  // Clean states
  for (uint8_t i = 0; i < MAX_RELAYS; i++) {
    relayStates[i] = false;
    pulseOffTimeMs[i] = 0;
  }
  
  // Set up pins
  for (uint8_t i = 0; i < relayConfigs.size(); i++) {
    if (i >= MAX_RELAYS) break;
    const auto& relay = relayConfigs[i];
    if (relay.enabled && relay.pin >= 0) {
      pinMode(relay.pin, OUTPUT);
      setRelayPinState(i, false);
    }
  }
}

#include "led_status_manager.h"
extern LedStatusManager gLedStatusManager;

void RelayManager::setRelayPinState(uint8_t index, bool isOn) {
  if (index >= relayConfigs.size() || index >= MAX_RELAYS) return;
  auto& relay = relayConfigs[index];
  if (!relay.enabled || relay.pin < 0) return;
  
  bool level = relay.activeLow ? !isOn : isOn;
  digitalWrite(relay.pin, level ? HIGH : LOW);
  relayStates[index] = isOn;
  relay.state = isOn;
}

void RelayManager::executeCommand(uint8_t relayId, const String& command, const String& revision) {
  // relayId is 1-based (from database), index is 0-based
  uint8_t index = relayId - 1;
  if (index >= relayConfigs.size() || index >= MAX_RELAYS) return;
  const auto& relay = relayConfigs[index];
  if (!relay.enabled) return;
  
  // De-duplicate commands by revision
  if (!revision.isEmpty() && lastRevisions[index] == revision) {
    return;
  }
  if (!revision.isEmpty()) {
    lastRevisions[index] = revision;
  }
  
  // Trigger blink feedback immediately on accepted command
  gLedStatusManager.triggerBlinkFeedback();
  
  Serial.printf("[RELAY] Command: %s on Relay %d (Pin: %d)\n", 
                command.c_str(), relayId, relay.pin);
                
  if (command == "ON") {
    pulseOffTimeMs[index] = 0; // Cancel active pulse
    setRelayPinState(index, true);
  } 
  else if (command == "OFF") {
    pulseOffTimeMs[index] = 0;
    setRelayPinState(index, false);
  } 
  else if (command == "PULSE" || (relay.pulseMs > 0 && command == "ON")) {
    uint16_t duration = relay.pulseMs > 0 ? relay.pulseMs : 250; // default 250ms
    setRelayPinState(index, true);
    pulseOffTimeMs[index] = millis() + duration;
  }
}

void RelayManager::storeRevisionOnly(uint8_t relayId, const String& revision) {
  uint8_t index = relayId - 1;
  if (index >= MAX_RELAYS) return;
  if (!revision.isEmpty()) {
    lastRevisions[index] = revision;
    Serial.printf("[RELAY] Boot-skip: stored revision for Relay %d (no execution)\n", relayId);
  }
}

void RelayManager::updatePulseTimers() {
  uint64_t now = millis();
  for (uint8_t i = 0; i < relayConfigs.size(); i++) {
    if (i >= MAX_RELAYS) break;
    if (pulseOffTimeMs[i] > 0 && now >= pulseOffTimeMs[i]) {
      pulseOffTimeMs[i] = 0;
      setRelayPinState(i, false);
      Serial.printf("[RELAY] Pulse completed on Relay %d\n", i + 1);
    }
  }
}

std::vector<RelayState> RelayManager::getAllStates() {
  std::vector<RelayState> states;
  for (uint8_t i = 0; i < relayConfigs.size(); i++) {
    if (i >= MAX_RELAYS) break;
    RelayState s;
    s.relayId = relayConfigs[i].id ? relayConfigs[i].id : (i + 1);
    s.isOn = relayStates[i];
    s.lastCommand = relayConfigs[i].enabled ? (relayStates[i] ? "ON" : "OFF") : "DISABLED";
    s.lastCommandTime = millis();
    s.commandRevision = lastRevisions[i];
    states.push_back(s);
  }
  return states;
}

bool RelayManager::getRelayState(uint8_t relayId) {
  uint8_t index = relayId - 1;
  if (index >= MAX_RELAYS) return false;
  return relayStates[index];
}

const RelayConfig* RelayManager::getRelayConfig(uint8_t relayId) const {
  uint8_t index = relayId - 1;
  if (index >= relayConfigs.size()) return nullptr;
  return &relayConfigs[index];
}
