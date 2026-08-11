#include "network_scanner.h"
#include <ETH.h>

extern "C" {
#include "lwip/etharp.h"
#include "lwip/tcpip.h"
#include "esp_netif_net_stack.h"
}

namespace {

// IPAddress's uint32_t cast is raw memory reinterpretation, which does NOT
// behave like normal dotted-quad arithmetic on a little-endian target
// (incrementing it would bump the *first* octet, not the last). These
// helpers do real big-endian/dotted-quad arithmetic via the octet accessors
// instead, so range math is always correct regardless of platform endianness.
uint32_t ipToOrdinal(const IPAddress& ip) {
  return (static_cast<uint32_t>(ip[0]) << 24) | (static_cast<uint32_t>(ip[1]) << 16) |
         (static_cast<uint32_t>(ip[2]) << 8) | static_cast<uint32_t>(ip[3]);
}

IPAddress ordinalToIp(uint32_t v) {
  return IPAddress((v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
}

struct netif* ethLwipNetif() {
  esp_netif_t* espNetif = ETH.netif();
  if (espNetif == nullptr) return nullptr;
  return static_cast<struct netif*>(esp_netif_get_netif_impl(espNetif));
}

String macToString(const uint8_t* addr) {
  char buf[18];
  snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X", addr[0], addr[1], addr[2], addr[3], addr[4], addr[5]);
  return String(buf);
}

}  // namespace

NetworkScanner::NetworkScanner() {}

void NetworkScanner::update() {
  uint32_t now = millis();

  if (!ETH.linkUp() || ETH.localIP() == IPAddress(0, 0, 0, 0)) {
    return;  // nothing to scan without a live IP
  }

  if (rangeStart == 0 || now - lastRangeRecomputeMs > kRangeRecomputeMs) {
    recomputeRange();
    lastRangeRecomputeMs = now;
  }

  if (now - lastProbeMs > kProbeIntervalMs) {
    lastProbeMs = now;
    probeNextHost();
  }

  if (now - lastHarvestMs > kHarvestIntervalMs) {
    lastHarvestMs = now;
    harvestArpTable();
  }
}

void NetworkScanner::recomputeRange() {
  IPAddress networkId = ETH.networkID();
  IPAddress broadcast = ETH.broadcastIP();

  uint32_t startOrd = ipToOrdinal(networkId) + 1;  // skip network address
  uint32_t endOrd = ipToOrdinal(broadcast);
  if (endOrd > startOrd) {
    endOrd -= 1;  // skip broadcast address
  }

  if (endOrd < startOrd) {
    // Degenerate (e.g. /31 or /32) — nothing sensible to sweep.
    rangeStart = 0;
    rangeEnd = 0;
    return;
  }

  // Safety cap so an unexpectedly large subnet (e.g. a /16) can't turn this
  // into an unbounded sweep — still lightweight, just covers fewer hosts.
  if (endOrd - startOrd + 1 > kMaxHostsPerSweep) {
    endOrd = startOrd + kMaxHostsPerSweep - 1;
  }

  rangeStart = startOrd;
  rangeEnd = endOrd;
  nextProbeOffset = 0;

  Serial.printf("[NETSCAN] Subnet range: %s - %s (%u hosts)\n", ordinalToIp(rangeStart).toString().c_str(),
                ordinalToIp(rangeEnd).toString().c_str(), rangeEnd - rangeStart + 1);
}

void NetworkScanner::probeNextHost() {
  if (rangeStart == 0 || rangeEnd < rangeStart) {
    return;
  }

  struct netif* netif = ethLwipNetif();
  if (netif == nullptr) {
    return;
  }

  uint32_t hostCount = rangeEnd - rangeStart + 1;
  IPAddress candidate = ordinalToIp(rangeStart + (nextProbeOffset % hostCount));
  nextProbeOffset = (nextProbeOffset + 1) % hostCount;

  if (candidate == ETH.localIP()) {
    return;  // no need to ARP ourselves
  }

  ip4_addr_t target;
  target.addr = static_cast<uint32_t>(candidate);

  // etharp_request() ultimately calls ethernet_output(), which asserts the
  // lwIP TCPIP core lock is held. This runs from the Arduino loop() task,
  // not the lwIP thread, so it must take that lock explicitly — omitting it
  // crashes the board (LWIP_ASSERT_CORE_LOCKED abort) rather than a graceful
  // failure.
  LOCK_TCPIP_CORE();
  etharp_request(netif, &target);  // fire-and-forget; replies land in lwIP's own ARP table
  UNLOCK_TCPIP_CORE();
}

void NetworkScanner::harvestArpTable() {
  struct netif* netif = ethLwipNetif();
  if (netif == nullptr) {
    return;
  }

  uint32_t now = millis();
  std::vector<bool> seenThisPass(knownDevices.size(), false);

  // etharp_get_entry() reads lwIP's live ARP table, which the lwIP thread
  // can mutate concurrently — same core-lock requirement as etharp_request()
  // above, just for reading instead of writing.
  LOCK_TCPIP_CORE();
  for (int i = 0; i < ARP_TABLE_SIZE; ++i) {
    ip4_addr_t* ipEntry = nullptr;
    struct netif* entryNetif = nullptr;
    struct eth_addr* ethEntry = nullptr;

    int valid = etharp_get_entry(static_cast<size_t>(i), &ipEntry, &entryNetif, &ethEntry);
    if (!valid || ipEntry == nullptr || ethEntry == nullptr) {
      continue;
    }

    IPAddress ip(ipEntry->addr);
    String mac = macToString(ethEntry->addr);

    DiscoveredDevice* existing = findByIp(ip);
    if (existing != nullptr) {
      size_t idx = existing - &knownDevices[0];
      if (idx < seenThisPass.size()) seenThisPass[idx] = true;
      if (!existing->active || existing->mac != mac) {
        dirty = true;
      }
      existing->mac = mac;
      existing->lastSeenMs = now;
      existing->active = true;
    } else {
      DiscoveredDevice device;
      device.ip = ip;
      device.mac = mac;
      device.hostname = "";  // no NBNS/mDNS resolution — kept intentionally lightweight
      device.lastSeenMs = now;
      device.active = true;
      knownDevices.push_back(device);
      dirty = true;
    }
  }
  UNLOCK_TCPIP_CORE();

  // Anything not present in this harvest pass ages toward inactive rather
  // than being dropped immediately — a device can miss one ARP cycle
  // without flapping the UI.
  for (size_t i = 0; i < knownDevices.size(); ++i) {
    if (i < seenThisPass.size() && seenThisPass[i]) continue;
    if (knownDevices[i].active && (now - knownDevices[i].lastSeenMs > kInactiveAfterMs)) {
      knownDevices[i].active = false;
      dirty = true;
    }
  }
}

DiscoveredDevice* NetworkScanner::findByIp(const IPAddress& ip) {
  for (auto& device : knownDevices) {
    if (device.ip == ip) {
      return &device;
    }
  }
  return nullptr;
}
