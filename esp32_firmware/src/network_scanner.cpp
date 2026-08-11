#include "network_scanner.h"
#include <ETH.h>
#include <cstring>

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

// etharp_request() ends up inside ethernet_output(), which this framework's
// ESP-IDF lwIP port hard-asserts on unless the CALLING TASK is specifically
// marked as the TCPIP core lock holder (LOCK_TCPIP_CORE() here expands to
// sys_mutex_lock() *plus* sys_thread_tcpip(LWIP_CORE_LOCK_MARK_HOLDER), an
// ESP-IDF-specific addition on top of stock lwIP — see
// framework-arduinoespressif32-libs/.../lwip/port/include/lwipopts.h).
// Taking that lock from the Arduino loop() task still crashed in testing,
// so instead of depending on that holder-marking behaving as expected from
// an arbitrary task, this uses lwIP's own officially-documented, always-safe
// mechanism for invoking raw API functions from another thread:
// tcpip_callback() queues the call to run for real on the TCPIP thread,
// where LWIP_ASSERT_CORE_LOCKED() is satisfied unconditionally because the
// code genuinely *is* running there.
struct ArpProbeRequest {
  struct netif* netif;
  ip4_addr_t target;
};

void arpProbeCallback(void* ctx) {
  ArpProbeRequest* req = static_cast<ArpProbeRequest*>(ctx);
  etharp_request(req->netif, &req->target);
  delete req;
}

// etharp_get_entry() is a read of lwIP's live ARP table rather than a
// transmit call, but nothing in the public headers proves it is exempt from
// the same TCPIP-thread requirement as etharp_request() above (no source is
// available in this framework install to confirm either way — see
// framework-arduinoespressif32-libs/esp32s3/include/lwip/lwip/src/include/
// lwip/etharp.h, declaration only). Rather than assume it's safe, this reads
// it via the same tcpip_callback mechanism, using the blocking variant
// (tcpip_callback_wait) so the harvest stays a simple synchronous call from
// NetworkScanner's perspective — the wait's semaphore hand-off also gives a
// proper memory barrier for the snapshot written by the TCPIP thread.
constexpr int kMaxArpSnapshot = ARP_TABLE_SIZE;

struct ArpSnapshotEntry {
  bool valid;
  uint32_t ip;  // ip4_addr_t.addr, native lwIP byte order
  uint8_t mac[6];
};

struct ArpHarvestCtx {
  ArpSnapshotEntry entries[kMaxArpSnapshot];
};

void arpHarvestCallback(void* ctxPtr) {
  ArpHarvestCtx* ctx = static_cast<ArpHarvestCtx*>(ctxPtr);
  for (int i = 0; i < kMaxArpSnapshot; ++i) {
    ip4_addr_t* ipEntry = nullptr;
    struct netif* entryNetif = nullptr;
    struct eth_addr* ethEntry = nullptr;

    int valid = etharp_get_entry(static_cast<size_t>(i), &ipEntry, &entryNetif, &ethEntry);
    if (!valid || ipEntry == nullptr || ethEntry == nullptr) {
      ctx->entries[i].valid = false;
      continue;
    }
    ctx->entries[i].valid = true;
    ctx->entries[i].ip = ipEntry->addr;
    memcpy(ctx->entries[i].mac, ethEntry->addr, sizeof(ctx->entries[i].mac));
  }
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

  ArpProbeRequest* req = new ArpProbeRequest();
  req->netif = netif;
  req->target.addr = static_cast<uint32_t>(candidate);

  // Non-blocking: queues onto the TCPIP thread and returns immediately.
  // Fire-and-forget — replies land in lwIP's own ARP table on their own. If
  // the TCPIP mailbox is briefly full, drop this probe rather than block
  // loop(); the next 750ms tick probes the next host in the sweep.
  if (tcpip_callback(arpProbeCallback, req) != ERR_OK) {
    delete req;
  }
}

void NetworkScanner::harvestArpTable() {
  struct netif* netif = ethLwipNetif();
  if (netif == nullptr) {
    return;
  }

  ArpHarvestCtx snapshot;
  memset(&snapshot, 0, sizeof(snapshot));
  if (tcpip_callback_wait(arpHarvestCallback, &snapshot) != ERR_OK) {
    return;  // couldn't safely read the ARP table this cycle — retry next harvest tick
  }

  uint32_t now = millis();
  std::vector<bool> seenThisPass(knownDevices.size(), false);

  for (int i = 0; i < kMaxArpSnapshot; ++i) {
    if (!snapshot.entries[i].valid) {
      continue;
    }

    IPAddress ip(snapshot.entries[i].ip);
    String mac = macToString(snapshot.entries[i].mac);

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
