#ifndef RELAY_MANAGER_H
#define RELAY_MANAGER_H

#include "pc_types.h"

class RelayManager {
 public:
  RelayManager();
  void initializeRelays(const std::vector<RelayConfig>& configs);
  void executeCommand(uint8_t relayId, const String& command, const String& revision);
  void storeRevisionOnly(uint8_t relayId, const String& revision);
  void clearRuntimeState();
  void updatePulseTimers();
  
  std::vector<RelayState> getAllStates();
  bool getRelayState(uint8_t relayId);
  const RelayConfig* getRelayConfig(uint8_t relayId) const;

 private:
  std::vector<RelayConfig> relayConfigs;
  bool relayStates[MAX_RELAYS];
  uint64_t pulseOffTimeMs[MAX_RELAYS];
  String lastRevisions[MAX_RELAYS];
  
  void setRelayPinState(uint8_t index, bool isOn);
};

#endif // RELAY_MANAGER_H
