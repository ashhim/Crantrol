#ifndef NETWORK_SCANNER_H
#define NETWORK_SCANNER_H

#include <Arduino.h>
#include <IPAddress.h>
#include <vector>

// Lightweight ARP-based LAN device inventory for the Ethernet segment the
// ESP32 is connected to. Adapts to whatever subnet DHCP/static config hands
// out — nothing is hardcoded. Uses lwIP's own ARP request/table (etharp_*)
// rather than a full port scanner: it trickles out one ARP request per host
// per tick (never floods the LAN) and periodically harvests whatever lwIP
// has already resolved into its ARP cache.
struct DiscoveredDevice {
  IPAddress ip;
  String mac;          // "AA:BB:CC:DD:EE:FF", empty if unresolved
  String hostname;      // best-effort; usually empty (no NBNS/mDNS lookup)
  uint32_t lastSeenMs;  // millis() timestamp of last confirmed ARP reply
  bool active;          // currently present in lwIP's live ARP table
};

class NetworkScanner {
 public:
  NetworkScanner();

  // Cheap, call every loop() iteration — internally rate-limited so it
  // costs at most one ARP request and one table scan per interval.
  void update();

  const std::vector<DiscoveredDevice>& devices() const { return knownDevices; }

  // True once the current in-memory device list differs materially from
  // what was last synced to Firebase (new device, device dropped off,
  // active/inactive flip). Caller should sync then call markSynced().
  bool hasMaterialChange() const { return dirty; }
  void markSynced() { dirty = false; }

 private:
  std::vector<DiscoveredDevice> knownDevices;

  // Sweep state — one host probed per tick, round-robins the subnet.
  uint32_t rangeStart = 0;  // host range, in natural (big-endian) integer form
  uint32_t rangeEnd = 0;
  uint32_t nextProbeOffset = 0;
  uint32_t lastProbeMs = 0;
  uint32_t lastHarvestMs = 0;
  uint32_t lastRangeRecomputeMs = 0;
  bool dirty = false;

  static constexpr uint32_t kProbeIntervalMs = 750;    // one ARP request per tick
  static constexpr uint32_t kHarvestIntervalMs = 5000;  // re-read lwIP's ARP table
  static constexpr uint32_t kRangeRecomputeMs = 30000;  // re-check subnet (DHCP renew, cable swap)
  static constexpr uint32_t kInactiveAfterMs = 5UL * 60UL * 1000UL;  // 5 min
  static constexpr uint32_t kMaxHostsPerSweep = 512;    // safety cap for large subnets

  void recomputeRange();
  void probeNextHost();
  void harvestArpTable();
  DiscoveredDevice* findByIp(const IPAddress& ip);
};

#endif  // NETWORK_SCANNER_H
