#ifndef ETHERNET_MANAGER_H
#define ETHERNET_MANAGER_H

#include <ETH.h>
#include <SPI.h>
#include <WiFi.h>
#include "pc_types.h"
#include "config.h"

class EthernetManager {
 public:
  EthernetManager();
  void initialize();
  void update();
  void reconnect();
  
  bool isPlugged() const { return ethernetPlugged; }
  bool isInternetAvailable() const { return internetAvailable; }
  String getLocalIp() const { return localIp; }
  NetworkStatus getStatus() const { return currentStatus; }
  
  void printNetworkInfo();
  bool checkInternet();

 private:
  NetworkStatus currentStatus;
  bool ethernetPlugged;
  bool internetAvailable;
  uint32_t lastConnectAttempt;
  uint32_t lastInternetCheck;
  String localIp;
  
  void updateConnectionStatus();
};

#endif // ETHERNET_MANAGER_H
