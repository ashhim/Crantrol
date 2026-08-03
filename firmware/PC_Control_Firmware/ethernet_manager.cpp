#include "ethernet_manager.h"
#include <WiFiClient.h>

// SPI class for Ethernet
static SPIClass* ethSPI = nullptr;

// Event handler pointer
static EthernetManager* g_ethManager = nullptr;

void handleEthEvent(arduino_event_t* event) {
  if (!g_ethManager) return;
  
  switch (event->event_id) {
    case ARDUINO_EVENT_ETH_START:
      Serial.println("[ETH] ETH Started");
      break;
    case ARDUINO_EVENT_ETH_CONNECTED:
      Serial.println("[ETH] ETH Connected");
      break;
    case ARDUINO_EVENT_ETH_GOT_IP: {
      IPAddress ip(event->event_info.got_ip.ip_info.ip.addr);
      Serial.printf("[ETH] Got IP: %s\n", ip.toString().c_str());
      break;
    }
    case ARDUINO_EVENT_ETH_LOST_IP:
      Serial.println("[ETH] Lost IP");
      break;
    case ARDUINO_EVENT_ETH_DISCONNECTED:
      Serial.println("[ETH] ETH Disconnected");
      break;
    case ARDUINO_EVENT_ETH_STOP:
      Serial.println("[ETH] ETH Stopped");
      break;
    default:
      break;
  }
}

EthernetManager::EthernetManager()
  : currentStatus(NetworkStatus::NOT_PLUGGED),
    ethernetPlugged(false),
    internetAvailable(false),
    lastConnectAttempt(0),
    lastInternetCheck(0) {
  g_ethManager = this;
}

void EthernetManager::initialize() {
  Serial.println("[ETH] Initializing W5500 SPI Ethernet...");
  
  // Set up custom SPI bus (HSPI is SPI2) for W5500 on Waveshare ESP32-S3-ETH
  if (ethSPI == nullptr) {
    ethSPI = new SPIClass(HSPI);
    ethSPI->begin(ETH_SCLK_PIN, ETH_MISO_PIN, ETH_MOSI_PIN, ETH_CS_PIN);
  }
  
  // Start Ethernet using Core 3.0 API signature:
  // ETH.begin(type, phy_addr, cs, irq, rst, spi_bus, spi_freq)
  // Waveshare board has phy_addr = 1 for W5500 in wiki/examples
  if (!ETH.begin(ETH_PHY_W5500, 1, ETH_CS_PIN, ETH_IRQ_PIN, ETH_RST_PIN, *ethSPI)) {
    Serial.println("[ETH] ETH.begin() failed!");
  } else {
    Serial.println("[ETH] ETH.begin() succeeded!");
  }
  
  // Set network event handler for Core 3.x
  Network.onEvent(handleEthEvent);
}

void EthernetManager::update() {
  updateConnectionStatus();
  
  // If Ethernet is plugged and we have an IP, but internet check is not yet verified, check more frequently (every 3s)
  // Otherwise check every 30 seconds
  uint32_t interval = (ethernetPlugged && ETH.localIP() && ETH.localIP() != IPAddress(0, 0, 0, 0) && !internetAvailable) 
                      ? 3000 
                      : INTERNET_CHECK_INTERVAL_MS;

  if (ethernetPlugged && (millis() - lastInternetCheck > interval || lastInternetCheck == 0)) {
    lastInternetCheck = millis();
    checkInternet();
  }
}

void EthernetManager::updateConnectionStatus() {
  bool wasPlugged = ethernetPlugged;
  ethernetPlugged = ETH.linkUp();
  
  // Handle cable unplugged
  if (!ethernetPlugged) {
    if (wasPlugged) {
      Serial.println("[ETH] EVENT: Ethernet cable unplugged");
      currentStatus = NetworkStatus::NOT_PLUGGED;
      internetAvailable = false;
    }
    return;
  }
  
  // Handle cable just plugged in
  if (!wasPlugged && ethernetPlugged) {
    Serial.println("[ETH] EVENT: Ethernet cable plugged in - waiting for IP");
  }
  
  // Check if we have a valid IP (non-zero)
  IPAddress currentIp = ETH.localIP();
  bool hasValidIp = (currentIp != IPAddress(0, 0, 0, 0));
  
  if (!hasValidIp) {
    if (currentStatus != NetworkStatus::PLUGGED_NO_IP) {
      Serial.println("[ETH] STATUS: Plugged but no IP address yet");
      currentStatus = NetworkStatus::PLUGGED_NO_IP;
      internetAvailable = false;
    }
    return;
  }
  
  // Update local IP string
  String newIp = currentIp.toString();
  if (newIp != localIp) {
    Serial.printf("[ETH] EVENT: IP acquired - %s\n", newIp.c_str());
    localIp = newIp;
  }
  
  // Update status based on internet availability
  if (!internetAvailable) {
    if (currentStatus != NetworkStatus::IP_ACQUIRED) {
      Serial.println("[ETH] STATUS: IP acquired but internet not yet verified");
      currentStatus = NetworkStatus::IP_ACQUIRED;
    }
  } else {
    if (currentStatus != NetworkStatus::INTERNET_READY) {
      Serial.println("[ETH] STATUS: Internet verified - connection ready");
      currentStatus = NetworkStatus::INTERNET_READY;
    }
  }
}

void EthernetManager::reconnect() {
  if (millis() - lastConnectAttempt < ETH_CONNECT_TIMEOUT_MS) {
    return;
  }
  
  if (!ethernetPlugged) {
    Serial.println("[ETH] Cannot reconnect: Ethernet not plugged");
    return;
  }
  
  if (ETH.linkUp() && ETH.localIP() && ETH.localIP() != IPAddress(0,0,0,0)) {
    Serial.println("[ETH] Already connected");
    return;
  }
  
  lastConnectAttempt = millis();
  Serial.println("[ETH] Attempting to reconnect...");
  initialize();
}

bool EthernetManager::checkInternet() {
  if (!ethernetPlugged || !ETH.localIP() || ETH.localIP() == IPAddress(0, 0, 0, 0)) {
    internetAvailable = false;
    currentStatus = NetworkStatus::IP_ACQUIRED;
    return false;
  }
  
  WiFiClient client;
  client.setTimeout(2000); // 2 seconds timeout
  
  // 1. Direct TCP IP Connection (bypasses DNS issues completely)
  // Try connecting to Cloudflare DNS IP (1.1.1.1) on port 80
  bool success = client.connect("1.1.1.1", 80);
  if (success) {
    client.stop();
  } else {
    // Try Google DNS (8.8.8.8) on port 53 (TCP)
    success = client.connect("8.8.8.8", 53);
    if (success) {
      client.stop();
    }
  }
  
  // 2. Fallback: DNS resolution of google.com if direct IP fails
  if (!success) {
    IPAddress dnsTest;
    int dnsResult = WiFi.hostByName("google.com", dnsTest);
    success = (dnsResult == 1 && dnsTest != IPAddress(0, 0, 0, 0));
  }
  
  bool wasAvailable = internetAvailable;
  internetAvailable = success;
  
  if (wasAvailable != internetAvailable) {
    if (internetAvailable) {
      Serial.println("[ETH] Internet is available (TCP connection succeeded)");
      currentStatus = NetworkStatus::INTERNET_READY;
    } else {
      Serial.println("[ETH] Internet check failed (TCP connection and DNS failed)");
      currentStatus = NetworkStatus::INTERNET_DOWN;
    }
  }
  
  return success;
}

void EthernetManager::printNetworkInfo() {
  Serial.println("\n[ETH] ===== Network Info =====");
  Serial.printf("  Plugged: %s\n", ethernetPlugged ? "Yes" : "No");
  Serial.printf("  IP: %s\n", localIp.c_str());
  Serial.printf("  MAC: %s\n", ETH.macAddress().c_str());
  Serial.printf("  Internet: %s\n", internetAvailable ? "Available" : "Unavailable");
  Serial.printf("  Status: %d\n", (int)currentStatus);
  Serial.println("============================\n");
}
