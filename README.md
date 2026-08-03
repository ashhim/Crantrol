# CRANTROL

**Version:** 1.0.0  
**Platform:** ESP32-S3 Ethernet (W5500)  
**Category:** IoT Remote Power & Device Control System  
**Architecture:** Distributed IoT System (ESP32 Firmware + Flutter Application + Firebase Backend)  
**Communication:** Ethernet + Firebase Realtime Database + Captive Portal  
**Relay Capacity:** 10 Relays (Expandable)  
**Storage:** ESP32 NVS + Flutter Local Storage (Hive & SharedPreferences)  
**Mobile Application:** Flutter (Android / iOS)  
**Development Frameworks:** Arduino Framework (PlatformIO) & Flutter  
**Programming Languages:** C++, Dart

---

## Contents

1. [System Overview](#system-overview)
2. [System Architecture](#system-architecture)
3. [Hardware Architecture](#hardware-architecture)
4. [Software Architecture](#software-architecture)
5. [Project Directory Structure](#project-directory-structure)
6. [ESP32 Firmware](#esp32-firmware)
7. [Flutter Mobile Application](#flutter-mobile-application)
8. [Firebase Cloud Backend](#firebase-cloud-backend)
9. [Relay Control System](#relay-control-system)
10. [Ethernet Communication](#ethernet-communication)
11. [Captive Portal Configuration](#captive-portal-configuration)
12. [Device Provisioning Workflow](#device-provisioning-workflow)
13. [Firebase Data Structure](#firebase-data-structure)
14. [Application Architecture](#application-architecture)
15. [Firmware Architecture](#firmware-architecture)
16. [Hardware Pin Mapping](#hardware-pin-mapping)
17. [Relay Configuration](#relay-configuration)
18. [Real-Time Synchronization](#real-time-synchronization)
19. [Online & Offline Detection](#online--offline-detection)
20. [Security & Environment Configuration](#security--environment-configuration)
21. [Build & Development Environment](#build--development-environment)
22. [Compilation & Build Process](#compilation--build-process)
23. [Flashing the ESP32 Firmware](#flashing-the-esp32-firmware)
24. [Building the Flutter Application](#building-the-flutter-application)
25. [Project Configuration](#project-configuration)
26. [Repository Structure](#repository-structure)
27. [Troubleshooting](#troubleshooting)
28. [Contributing](#contributing)
29. [License](#license)

---

## System Overview

CRANTROL is a distributed IoT remote control platform designed to manage computers, networking equipment, and other electrical devices through a dedicated ESP32-S3 Ethernet controller and a Flutter-based mobile application.

The system combines embedded firmware, a cross-platform mobile application, and Firebase Realtime Database to provide low-latency remote control with real-time synchronization. It is designed around a modular 10-relay architecture that can be expanded to support additional hardware without redesigning the overall software architecture.

Unlike traditional Wi-Fi relay controllers, CRANTROL primarily communicates over Ethernet using a W5500 Ethernet controller, providing a more stable and reliable connection for always-on installations. During initial setup or network reconfiguration, the controller automatically creates a captive portal, allowing device configuration directly from a web browser without requiring firmware modifications.

The mobile application communicates with the controller through Firebase Realtime Database, enabling secure remote operation from anywhere with internet connectivity. Relay states, device configuration, heartbeat information, online status, timers, and system events remain synchronized across all connected mobile devices in real time.

The firmware is responsible for:

- Managing Ethernet connectivity
- Maintaining Firebase communication
- Executing relay commands
- Monitoring device status
- Providing captive portal configuration
- Managing persistent configuration storage
- Controlling status indicators and buzzer feedback

The Flutter application provides an industrial-inspired user interface for:

- Real-time relay control
- Device monitoring
- Configuration management
- System diagnostics
- Online/offline monitoring
- Timer synchronization
- Device provisioning
- User authentication

The current implementation supports ten independently configurable relay outputs by default, allowing CRANTROL to control devices such as:

- Desktop computers
- Servers
- Monitors
- Speakers
- Network switches
- Routers
- Modems
- Power supplies
- Lighting systems
- Any relay-controlled electrical equipment

Each relay can be configured individually with custom names, GPIO assignments, pulse durations, and operating modes while maintaining synchronization across the firmware, Firebase backend, and every connected mobile application.

CRANTROL has been designed as a modular platform where additional relay channels, automation features, or hardware modules can be integrated with minimal architectural changes.

---

## System Architecture

CRANTROL follows a distributed three-layer architecture consisting of a mobile application, a cloud synchronization layer, and an embedded controller. Each layer has a dedicated responsibility, allowing the system to remain modular, scalable, and easy to maintain.

Rather than communicating directly with the ESP32 over a local network, the mobile application exchanges commands and status information through Firebase Realtime Database. The ESP32 continuously synchronizes with Firebase over Ethernet, enabling secure remote access from anywhere with an internet connection.

The architecture separates user interaction, cloud synchronization, and hardware control into independent components.

```
                           CRANTROL SYSTEM

                    ┌───────────────────────────┐
                    │     Flutter Mobile App    │
                    │        (Android/iOS)      │
                    └─────────────┬─────────────┘
                                  │
                                  │ Firebase SDK
                                  │
                                  ▼
                 ┌─────────────────────────────────┐
                 │ Firebase Realtime Database       │
                 │                                 │
                 │ • Relay Commands                │
                 │ • Device Configuration          │
                 │ • Device Status                 │
                 │ • Heartbeat                     │
                 │ • Online Status                 │
                 │ • Relay Timers                 │
                 └─────────────────┬──────────────┘
                                   │
                     Secure Ethernet Connection
                                   │
                                   ▼
                 ┌─────────────────────────────────┐
                 │ ESP32-S3 Ethernet Controller    │
                 │                                 │
                 │ • Firebase Client              │
                 │ • Relay Manager                │
                 │ • Ethernet Manager             │
                 │ • Captive Portal               │
                 │ • Configuration Manager        │
                 │ • Status & Heartbeat Manager   │
                 └─────────────────┬──────────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
                ▼                  ▼                  ▼
          Relay Outputs      Status LEDs        Buzzer Feedback
                │
                ▼
     PC • Monitor • Speaker • Router • Modem
     Network Switch • Lighting • Any Relay Device
```

### Architectural Layers

### 1. Presentation Layer

The presentation layer consists of the Flutter mobile application responsible for all user interactions.

Its responsibilities include:

- User authentication
- Dashboard rendering
- Relay control
- Device configuration
- Timer visualization
- Real-time status monitoring
- Online/offline indication
- Settings management

The application never communicates directly with the hardware. All interactions occur through Firebase.

---

### 2. Cloud Synchronization Layer

Firebase Realtime Database acts as the communication bridge between the mobile application and the embedded controller.

This layer is responsible for:

- Synchronizing relay states
- Delivering user commands
- Storing device configuration
- Maintaining heartbeat information
- Synchronizing timers
- Reporting device status
- Broadcasting updates to every connected client

Because all state changes pass through Firebase, multiple mobile devices remain synchronized without requiring local network discovery.

---

### 3. Embedded Control Layer

The embedded layer runs on an ESP32-S3 with a W5500 Ethernet controller.

Its responsibilities include:

- Maintaining Ethernet connectivity
- Authenticating with Firebase
- Receiving relay commands
- Driving relay hardware
- Monitoring network status
- Updating heartbeat information
- Executing pulse operations
- Managing LEDs and buzzer
- Hosting the captive portal
- Persisting configuration using NVS

This layer is responsible for all hardware interaction and operates independently of the mobile application.

---

### Data Flow

A typical relay operation follows the sequence below:

```
User
 │
 ▼
Flutter Application
 │
 ▼
Firebase Realtime Database
 │
 ▼
ESP32 Firmware
 │
 ▼
Relay Output
 │
 ▼
Physical Device

            ▲
            │
     Status / Heartbeat
            │
            └────────────── Firebase ──────────────► Flutter
```

Every hardware state change is reported back through Firebase, allowing all connected applications to display the current device state in real time.

---

### Design Principles

The CRANTROL architecture has been designed around the following principles:

- Modular software components
- Hardware abstraction
- Cloud-based synchronization
- Real-time communication
- Persistent configuration storage
- Expandable relay architecture
- Independent firmware and application development
- Reliable Ethernet communication
- Remote accessibility from anywhere
- Simple device provisioning through a captive portal

---

The result is a scalable IoT platform capable of remotely controlling computers and other relay-driven equipment while maintaining reliable synchronization between embedded hardware, cloud infrastructure, and every connected mobile application.

---


## Hardware Architecture

The CRANTROL hardware platform is built around an ESP32-S3 microcontroller paired with a W5500 Ethernet controller, providing reliable wired network connectivity for continuous remote operation.

The controller interfaces with a ten-channel relay system, status indicators, an onboard buzzer, and a captive portal configuration interface, forming a dedicated embedded controller capable of remotely operating computers and other electrical equipment.

The hardware has been designed to be modular, allowing relay channels and peripheral devices to be expanded without requiring significant firmware modifications.

---

## Hardware Overview

| Component | Description |
|-----------|-------------|
| Microcontroller | ESP32-S3 |
| Network Interface | W5500 Ethernet Controller |
| Communication | Ethernet (Primary), Wi-Fi (Captive Portal Configuration) |
| Relay Outputs | 10 Channels (Expandable) |
| Status Indicators | Status LED, Network LED, RGB LED |
| Audible Feedback | Active Buzzer |
| Configuration | Captive Portal |
| Configuration Storage | ESP32 Non-Volatile Storage (NVS) |

---

## Hardware Block Diagram

```text
                 ┌──────────────────────────┐
                 │     Flutter App          │
                 └────────────┬─────────────┘
                              │
                        Firebase Cloud
                              │
                 Ethernet Communication
                              │
                 ┌────────────▼─────────────┐
                 │      ESP32-S3 MCU        │
                 └───────┬───────┬──────────┘
                         │       │
                W5500 Ethernet   Wi-Fi AP
                         │       │
                         │   Captive Portal
                         │
          ┌──────────────┼───────────────┐
          │              │               │
          ▼              ▼               ▼
     Relay Outputs   Status LEDs      Buzzer
          │
          ▼
PC • Monitor • Speaker • Switch • Router • Modem
Lighting • Power Supply • Other Relay Devices
```

---

## ESP32-S3 GPIO Assignments

### Relay Outputs

| Relay | GPIO | Default Function |
|-------:|-----:|------------------|
| Relay 1 | GPIO 21 | PC Power |
| Relay 2 | GPIO 17 | Monitor 1 |
| Relay 3 | GPIO 16 | Monitor 2 |
| Relay 4 | GPIO 18 | Motherboard Power Button |
| Relay 5 | GPIO 15 | General Purpose |
| Relay 6 | GPIO 3 | General Purpose |
| Relay 7 | GPIO 2 | General Purpose |
| Relay 8 | GPIO 1 | General Purpose |
| Relay 9 | GPIO 0 | Power |
| Relay 10 | GPIO 44 | Reset |

---

### System Indicators

| Device | GPIO |
|---------|-----:|
| Buzzer | GPIO 43 |
| Status LED | GPIO 47 |
| Network LED | GPIO 48 |
| RGB LED | GPIO 46 |

---

### W5500 Ethernet Interface

| Signal | GPIO |
|---------|-----:|
| MISO | GPIO 12 |
| MOSI | GPIO 11 |
| SCLK | GPIO 13 |
| CS | GPIO 14 |
| IRQ | GPIO 10 |
| RESET | GPIO 9 |

---

## Relay System

CRANTROL currently supports **10 independent relay outputs**.

Each relay can be configured individually with:

- Custom relay name
- GPIO assignment
- Enable or disable state
- Active High / Active Low operation
- Pulse duration
- Latched or pulse operation

The firmware has been designed around a modular relay abstraction, making it straightforward to expand beyond ten relays in future hardware revisions.

---

## Network Architecture

The hardware primarily communicates through the W5500 Ethernet controller for stable and reliable operation.

When initial configuration or network recovery is required, the ESP32 automatically enables a Wi-Fi Access Point and captive portal, allowing users to configure device settings directly from a web browser without reflashing the firmware.

Default configuration:

| Parameter | Default |
|-----------|---------|
| AP Name | PC-Control-Setup |
| AP Password | 12345678 |

---

## Status Indicators

The controller provides visual and audible feedback through dedicated indicators.

### Status LED

Indicates overall device operation and firmware status.

### Network LED

Displays Ethernet and cloud connectivity status.

### RGB LED

Provides additional system state indication during operation and setup.

### Buzzer

Provides audible feedback for:

- Relay operations
- Button interactions
- System alerts
- Network events
- Configuration events

---

## Connected Devices

Although originally developed for remote PC control, CRANTROL can operate virtually any relay-controlled electrical equipment.

Typical examples include:

- Desktop computers
- Servers
- Monitors
- Speakers
- Routers
- Network switches
- Modems
- Lighting systems
- Smart power distribution
- Custom electrical equipment

---

The hardware platform has been designed to separate hardware control from cloud communication and user interaction, allowing the firmware, mobile application, and cloud backend to evolve independently while maintaining a consistent hardware interface.

---


## Software Architecture

CRANTROL follows a modular, layered software architecture that separates the user interface, cloud communication, and embedded hardware control into independent components. Each layer is responsible for a specific part of the system while communicating through clearly defined interfaces.

This separation allows the mobile application, cloud backend, and ESP32 firmware to evolve independently without affecting the overall operation of the system.

---

## Software Stack

| Layer | Technology |
|--------|------------|
| Mobile Application | Flutter (Dart) |
| State Management | Provider |
| Cloud Backend | Firebase Realtime Database |
| Authentication | Firebase Authentication |
| Embedded Firmware | Arduino Framework (PlatformIO) |
| Microcontroller | ESP32-S3 |
| Communication | Ethernet (W5500) |
| Local Configuration | NVS, Hive, SharedPreferences |

---

## Software Layers

```
                     CRANTROL SOFTWARE STACK

┌─────────────────────────────────────────────────────┐
│                 Flutter Mobile App                  │
│                                                     │
│ Dashboard • Relays • Settings • Login • Sequences  │
└──────────────────────────┬──────────────────────────┘
                           │
                           │ Firebase SDK
                           ▼
┌─────────────────────────────────────────────────────┐
│            Firebase Realtime Database               │
│                                                     │
│ Relay States • Device Status • Timers              │
│ Configuration • Heartbeat • Authentication         │
└──────────────────────────┬──────────────────────────┘
                           │
                           │ Ethernet
                           ▼
┌─────────────────────────────────────────────────────┐
│               ESP32 Firmware Layer                  │
│                                                     │
│ Firebase Client                                     │
│ Ethernet Manager                                    │
│ Relay Manager                                       │
│ Configuration Manager                               │
│ LED Status Manager                                  │
│ Captive Portal                                      │
└──────────────────────────┬──────────────────────────┘
                           │
                           ▼
                    Relay Hardware
```

---

## Mobile Application

The Flutter application provides the primary interface for interacting with the CRANTROL controller.

Its responsibilities include:

- User authentication
- Device discovery
- Dashboard visualization
- Relay control
- Device configuration
- Timer visualization
- Online/offline monitoring
- System settings
- Real-time synchronization

The application never communicates directly with GPIO hardware. Every operation is performed through Firebase.

---

## Cloud Layer

Firebase Realtime Database acts as the synchronization layer between every connected mobile application and the ESP32 controller.

The cloud layer manages:

- Relay commands
- Relay states
- Device configuration
- Device heartbeat
- Online status
- Timer synchronization
- System commands

Because Firebase serves as the communication bridge, multiple mobile devices always remain synchronized with the latest hardware state.

---

## Embedded Firmware

The ESP32 firmware is responsible for interacting with the physical hardware.

Major firmware responsibilities include:

- Ethernet communication
- Firebase synchronization
- Relay control
- Captive portal management
- Persistent configuration storage
- Device heartbeat updates
- Status LED control
- Buzzer feedback
- System monitoring

The firmware continuously synchronizes with Firebase while independently managing the connected hardware.

---

## Flutter Project Structure

The Flutter application is organized into modular components.

```
lib/
├── models/
├── providers/
├── screens/
├── services/
├── utils/
├── widgets/
└── main.dart
```

### Models

Defines application data structures and serialization.

Examples:

- Device model
- Relay configuration
- Firebase object mapping

---

### Providers

Implements application state management using the Provider package.

Responsible for:

- Device state
- Authentication
- Relay updates
- Firebase synchronization

---

### Screens

Contains the application's user interface.

Current screens include:

- Login
- Dashboard
- Relays
- Sequences
- Settings

---

### Services

Implements external integrations.

Current services include:

- Firebase communication
- Environment configuration
- Firebase initialization

---

### Widgets

Contains reusable UI components shared throughout the application.

---

### Utilities

Provides shared themes, constants, helper classes, and application-wide styling.

---

## Firmware Project Structure

The embedded firmware follows a modular architecture.

```
esp32_firmware/
├── include/
├── src/
├── scripts/
├── data/
└── platformio.ini
```

### include/

Contains shared headers, configuration definitions, GPIO mappings, and common data structures.

### src/

Contains the firmware implementation, including:

- main.cpp
- ethernet_manager
- firebase_client
- relay_manager
- led_status_manager
- configuration_manager

### scripts/

Contains PlatformIO helper scripts used during compilation and environment loading.

### data/

Contains files served by the captive portal when required.

---

## Software Design Principles

CRANTROL has been developed around several core principles:

- Modular architecture
- Separation of concerns
- Real-time synchronization
- Hardware abstraction
- Cloud-based communication
- Expandable relay management
- Maintainable source structure
- Independent firmware and application development

---

This architecture enables CRANTROL to remain scalable while ensuring that changes to one software layer have minimal impact on the others, making future expansion and maintenance significantly easier.

---


## Project Directory Structure

The CRANTROL repository is organized into independent modules for the mobile application, embedded firmware, cloud configuration, and project documentation. This separation keeps each component maintainable while allowing the system to evolve without affecting unrelated parts.

```
Crantrol-main/
│
├── applicatoin/                     # Flutter Mobile Application
│   ├── android/                     # Android platform
│   ├── ios/                         # iOS platform
│   ├── linux/                       # Linux platform
│   ├── macos/                       # macOS platform
│   ├── web/                         # Web platform
│   ├── windows/                     # Windows platform
│   ├── assets/                      # Images, icons and application assets
│   ├── lib/                         # Flutter source code
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── utils/
│   │   ├── widgets/
│   │   └── main.dart
│   ├── test/                        # Unit tests
│   ├── pubspec.yaml
│   └── README.md
│
├── esp32_firmware/                  # Primary ESP32-S3 Firmware
│   ├── include/                     # Header files
│   ├── src/                         # Firmware source files
│   ├── data/                        # Captive portal web assets
│   ├── scripts/                     # PlatformIO helper scripts
│   ├── platformio.ini
│   └── README.md
│
├── firmware/
│   ├── PC_Control_Firmware/         # Arduino IDE compatible firmware
│   └── README.md
│
├── firebase/                        # Firebase configuration
│   ├── firestore_rules.txt
│   └── rtdb_rules.json
│
├── .env.example                     # Example environment configuration
├── .gitignore
│
├── README.md
├── QUICK_REFERENCE.md
├── IMPLEMENTATION_GUIDE.md
├── BUILD_REPORT.md
├── DEPLOYMENT_CHECKLIST.md
├── PROJECT_AUDIT.md
├── PROJECT_COMPLETION_SUMMARY.md
└── FILE_MANIFEST.md
```

---

## Repository Overview

The repository is divided into four primary modules.

### Flutter Application (`applicatoin/`)

Contains the complete cross-platform mobile application developed using Flutter.

Primary responsibilities include:

- User authentication
- Dashboard interface
- Relay control
- Device configuration
- Firebase communication
- Real-time synchronization
- Timer management
- Settings management

---

### ESP32 Firmware (`esp32_firmware/`)

Contains the primary firmware running on the ESP32-S3 Ethernet controller.

Key components include:

```
include/
```

Shared headers, hardware definitions, GPIO mappings, configuration constants, and common data structures.

```
src/
```

Core firmware modules including:

- `main.cpp`
- `relay_manager.cpp`
- `firebase_client.cpp`
- `ethernet_manager.cpp`
- `led_status_manager.cpp`
- `captive_portal.cpp`

```
scripts/
```

PlatformIO helper scripts used during the build process, including environment loading.

```
data/
```

Files served by the captive portal web interface.

---

### Arduino Firmware (`firmware/PC_Control_Firmware/`)

Provides an Arduino IDE compatible version of the firmware.

This directory mirrors the PlatformIO implementation while allowing users to build and upload firmware directly from the Arduino IDE.

---

### Firebase (`firebase/`)

Contains cloud configuration files used by the backend.

Current files include:

- Firebase Realtime Database security rules
- Firestore security rules

No application logic is stored in this directory.

---

## Documentation Files

The repository includes several documentation files covering different aspects of the project.

| File | Purpose |
|------|---------|
| README.md | Complete project documentation |
| QUICK_REFERENCE.md | Quick setup and development reference |
| IMPLEMENTATION_GUIDE.md | Implementation details |
| BUILD_REPORT.md | Build verification information |
| DEPLOYMENT_CHECKLIST.md | Deployment procedure |
| PROJECT_AUDIT.md | Project audit information |
| PROJECT_COMPLETION_SUMMARY.md | Development summary |
| FILE_MANIFEST.md | Repository file listing |

---

## Architectural Separation

The repository is intentionally organized so each major subsystem remains independent.

```
Flutter App
        │
        ▼
Firebase Backend
        │
        ▼
ESP32 Firmware
        │
        ▼
Relay Hardware
```

This separation allows each module to be developed, tested, and maintained independently while communicating through well-defined interfaces.

---

The current repository structure provides a scalable foundation for future expansion, allowing additional firmware modules, mobile features, cloud services, or hardware revisions to be integrated without restructuring the overall project.

---


## ESP32 Firmware

The ESP32 firmware is the core of the CRANTROL platform. Running on an ESP32-S3 microcontroller with a W5500 Ethernet controller, it is responsible for managing hardware peripherals, maintaining cloud communication, executing relay operations, and coordinating every interaction between the physical controller and the Flutter application.

Designed with a modular architecture, each subsystem is implemented as an independent component with a clearly defined responsibility. This approach simplifies maintenance, testing, and future expansion while keeping the main application logic concise.

---

## Firmware Responsibilities

The firmware is responsible for:

- Initializing the ESP32 hardware
- Managing Ethernet connectivity through the W5500 controller
- Establishing and maintaining Firebase communication
- Executing relay control commands
- Synchronizing relay states
- Hosting the captive portal during configuration
- Managing persistent configuration storage
- Monitoring device status
- Updating heartbeat information
- Controlling LEDs and buzzer feedback
- Processing system commands
- Maintaining real-time synchronization with the mobile application

---

## Firmware Architecture

```
                  ESP32 Firmware

                  main.cpp
                      │
      ┌───────────────┼───────────────┐
      │               │               │
      ▼               ▼               ▼
Relay Manager   Ethernet Manager   Firebase Client
      │               │               │
      └───────────────┼───────────────┘
                      │
              Runtime State
                      │
      ┌───────────────┼───────────────┐
      ▼               ▼               ▼
 LED Status      Captive Portal   Configuration
   Manager
```

Each module performs a dedicated function while communicating through shared runtime structures.

---

## Main Firmware Entry Point

The firmware begins execution in `main.cpp`.

Primary responsibilities include:

- Initializing hardware
- Loading configuration
- Initializing relay outputs
- Starting Ethernet
- Connecting to Firebase
- Starting the captive portal when required
- Running the main event loop
- Scheduling periodic tasks

The application loop continuously performs:

- Network monitoring
- Firebase synchronization
- Relay updates
- LED status updates
- Heartbeat transmission
- Captive portal servicing

---

## Core Firmware Modules

### Relay Manager

**Files**

```
include/relay_manager.h
src/relay_manager.cpp
```

Responsible for all relay operations.

Features include:

- Relay initialization
- GPIO control
- Relay state management
- Pulse operation
- Relay synchronization
- Individual relay configuration
- Multi-relay support

Every physical relay operation passes through this module.

---

### Firebase Client

**Files**

```
include/firebase_client.h
src/firebase_client.cpp
```

Provides communication with Firebase Realtime Database.

Responsibilities include:

- Authentication
- Reading relay commands
- Writing relay status
- Uploading heartbeat information
- Configuration synchronization
- Online status updates
- Device information synchronization

The firmware never communicates directly with the mobile application. Firebase acts as the communication bridge.

---

### Ethernet Manager

**Files**

```
include/ethernet_manager.h
src/ethernet_manager.cpp
```

Handles all wired network communication.

Responsibilities include:

- W5500 initialization
- Ethernet link monitoring
- IP configuration
- Connection recovery
- Internet availability detection

This module provides a stable network connection for continuous operation.

---

### LED Status Manager

**Files**

```
include/led_status_manager.h
src/led_status_manager.cpp
```

Controls visual and audible feedback.

Managed devices include:

- Status LED
- Network LED
- RGB LED
- Buzzer

The manager provides immediate feedback for:

- Relay operations
- Network status
- System startup
- Errors
- Alerts
- Configuration events

---

### Captive Portal

**Files**

```
include/captive_portal.h
src/captive_portal.cpp
```

Provides local configuration without requiring firmware recompilation.

Functions include:

- Creating a temporary Wi-Fi Access Point
- Hosting a configuration web interface
- Receiving user configuration
- Saving configuration to persistent storage
- Restarting the controller when configuration changes

The captive portal is primarily intended for first-time setup or network recovery.

---

## Shared Configuration

Most hardware definitions and system constants are centralized within the firmware include directory.

```
include/
├── config.h
├── pc_types.h
├── relay_manager.h
├── firebase_client.h
├── ethernet_manager.h
├── captive_portal.h
└── led_status_manager.h
```

These files define:

- GPIO assignments
- Relay configuration
- Ethernet configuration
- Firebase configuration
- Shared data structures
- Runtime configuration
- Compile-time constants

Centralizing configuration simplifies maintenance and keeps module interfaces consistent.

---

## Runtime State

The firmware maintains shared runtime structures that are accessed by multiple modules.

These structures contain information such as:

- Relay states
- Network status
- Device status
- Current configuration
- System timers
- Heartbeat information
- Synchronization status

This shared runtime model allows independent modules to cooperate without duplicating state information.

---

## Main Execution Cycle

The firmware continuously executes a non-blocking event loop.

Typical execution flow:

```
Initialize Hardware
        │
        ▼
Load Configuration
        │
        ▼
Start Ethernet
        │
        ▼
Connect to Firebase
        │
        ▼
Initialize Relays
        │
        ▼
Enter Main Loop
        │
        ├── Check Network
        ├── Sync Firebase
        ├── Update Relays
        ├── Update LEDs
        ├── Process Commands
        ├── Update Heartbeat
        └── Service Captive Portal
```

This event-driven architecture keeps the controller responsive while avoiding unnecessary blocking operations.

---

## Design Principles

The firmware has been developed around several key principles:

- Modular architecture
- Separation of responsibilities
- Non-blocking execution
- Reliable Ethernet communication
- Real-time cloud synchronization
- Persistent configuration storage
- Expandable relay management
- Hardware abstraction
- Maintainable code structure

These principles allow new hardware features, communication methods, or relay modules to be added with minimal impact on the existing codebase.

---

The ESP32 firmware serves as the operational core of CRANTROL, bridging cloud services and physical hardware while ensuring reliable, synchronized control of every connected relay and device.

---


## Flutter Mobile Application

The CRANTROL mobile application serves as the primary user interface for the entire platform. Developed using Flutter, it provides a responsive, cross-platform experience for monitoring devices, controlling relays, configuring hardware, and managing the controller from anywhere through Firebase Realtime Database.

The application has been designed with a modular architecture that separates user interface components, business logic, cloud communication, and application state into dedicated layers. This approach improves maintainability, scalability, and simplifies future feature development.

---

## Application Overview

| Property | Description |
|----------|-------------|
| Framework | Flutter |
| Programming Language | Dart |
| State Management | Provider |
| Backend | Firebase Realtime Database |
| Authentication | Firebase Authentication |
| Local Storage | Hive + SharedPreferences |
| UI Style | Industrial Dashboard |
| Supported Platforms | Android, iOS, Windows, Linux, macOS, Web |

---

## Application Responsibilities

The Flutter application is responsible for:

- User authentication
- Device monitoring
- Relay control
- Real-time synchronization
- Device configuration
- Relay timer visualization
- Online/offline monitoring
- Firmware interaction through Firebase
- System settings
- User preferences

The application never communicates directly with the ESP32 hardware. Every interaction is synchronized through Firebase Realtime Database.

---

## Application Architecture

```
                    Flutter Application

                     main.dart
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
      Screens        Providers       Services
         │               │               │
         └───────────────┼───────────────┘
                         │
                  Models & Utilities
                         │
                         ▼
               Firebase Realtime Database
```

Each layer is responsible for a single area of the application, minimizing dependencies between components.

---

## Application Structure

```
lib/
├── models/
├── providers/
├── screens/
├── services/
├── utils/
├── widgets/
└── main.dart
```

---

## Entry Point

### `main.dart`

The application starts from `main.dart`.

Its responsibilities include:

- Initializing Flutter
- Loading environment configuration
- Initializing Firebase
- Registering providers
- Applying application theme
- Launching the authentication flow
- Configuring navigation

---

## Models

```
lib/models/
```

The models layer defines the application's data structures.

Current models include:

- Device model
- Relay information
- Serialization helpers

These models provide a common data representation shared between Firebase, the UI, and state management.

---

## Providers

```
lib/providers/
```

The Provider package is used for centralized state management.

Current providers include:

### Authentication Provider

Responsible for:

- User sign-in
- User sign-out
- Authentication state
- Session management

### Device Provider

Responsible for:

- Relay state synchronization
- Device configuration
- Online/offline monitoring
- Timer updates
- Firebase communication
- Device status management

Providers act as the bridge between Firebase services and the user interface.

---

## Screens

```
lib/screens/
```

The user interface is divided into independent screens.

### Login Screen

Provides Firebase Authentication and secure access to the controller.

---

### Dashboard

The Dashboard is the central control interface.

Features include:

- Device status
- Relay overview
- PC control
- Power controls
- Relay timers
- Online/offline indication
- System commands

---

### Relays

Provides detailed control and configuration for each relay.

Users can:

- Rename relays
- Change GPIO assignments
- Configure pulse duration
- Toggle relay state
- View relay information

---

### Sequences

Provides predefined relay sequences and automation routines.

---

### Settings

Provides system configuration including:

- Device information
- User account management
- Application settings
- Logout functionality

---

## Services

```
lib/services/
```

Services provide external integrations used throughout the application.

### Firebase Service

Handles all communication with Firebase Realtime Database.

Responsibilities include:

- Reading relay states
- Sending commands
- Updating configuration
- Monitoring device status
- Authentication support

---

### Environment Service

Loads runtime configuration and environment variables required by the application.

This separates sensitive configuration values from the application source code.

---

### Firebase Options

Contains the Firebase initialization configuration used during application startup.

---

## Utilities

```
lib/utils/
```

Utility classes provide application-wide functionality including:

- Theme configuration
- Shared constants
- Helper methods

The application's industrial design language is centralized within this layer.

---

## Widgets

```
lib/widgets/
```

Reusable widgets are stored separately from screens to encourage component reuse.

Examples include:

- Common buttons
- Status indicators
- Shared dialog components
- Reusable UI elements

This minimizes duplicated code throughout the application.

---

## Firebase Integration

The application communicates exclusively through Firebase Realtime Database.

Typical communication flow:

```
User
 │
 ▼
Flutter UI
 │
 ▼
Provider
 │
 ▼
Firebase Service
 │
 ▼
Firebase Realtime Database
 │
 ▼
ESP32 Firmware
```

Hardware responses follow the same path in reverse, allowing every connected device to remain synchronized.

---

## Real-Time Synchronization

The application continuously listens for updates from Firebase.

Automatically synchronized data includes:

- Relay states
- Relay timers
- Device configuration
- Online status
- Heartbeat information
- System status

As changes occur, the user interface updates automatically without requiring manual refreshes.

---

## User Interface Design

CRANTROL follows an industrial-inspired design language focused on clarity and usability.

Design principles include:

- Dark interface
- High-contrast status indicators
- Industrial control styling
- Real-time visual feedback
- Responsive layouts
- Consistent navigation
- Minimal interaction steps

The interface is designed to provide quick access to essential controls while maintaining a clean and organized appearance.

---

## Design Principles

The Flutter application has been developed around several core principles:

- Modular architecture
- Separation of concerns
- Reactive state management
- Cloud-first synchronization
- Component reusability
- Responsive user interface
- Scalable project structure
- Cross-platform compatibility

---

The Flutter mobile application provides the primary interaction layer of CRANTROL, delivering a responsive, real-time interface that seamlessly connects users with the embedded controller through Firebase while maintaining a consistent experience across supported platforms.

---


## Firebase Cloud Backend

Firebase serves as the cloud communication layer of the CRANTROL platform, providing secure, real-time synchronization between the Flutter mobile application and the ESP32-S3 controller.

Rather than establishing a direct connection between the application and the embedded hardware, both systems communicate through Firebase Realtime Database. This architecture enables remote access from anywhere with an internet connection while keeping every connected client synchronized with the latest device state.

Firebase also manages user authentication and enforces database security rules, ensuring that only authenticated users can access or modify device data.

---

## Backend Overview

| Service | Purpose |
|----------|---------|
| Firebase Realtime Database | Real-time synchronization between the application and the ESP32 |
| Firebase Authentication | User authentication and secure access |
| Firebase Security Rules | Read/write access validation |
| Firestore Rules | Reserved for future expansion (currently disabled) |

---

## Backend Architecture

```
                  CRANTROL Cloud Backend

        ┌─────────────────────────────────────┐
        │      Flutter Mobile Application     │
        └──────────────────┬──────────────────┘
                           │
                    Firebase Authentication
                           │
                           ▼
               Firebase Realtime Database
                           ▲
                           │
                    Ethernet Connection
                           │
        ┌──────────────────┴──────────────────┐
        │     ESP32-S3 Ethernet Controller    │
        └─────────────────────────────────────┘
```

Firebase acts as the single communication bridge between every mobile application and the embedded controller.

---

## Primary Responsibilities

The Firebase backend is responsible for:

- User authentication
- Relay command synchronization
- Device configuration storage
- Relay state synchronization
- Online/offline status updates
- Heartbeat synchronization
- Timer synchronization
- System command delivery
- Configuration persistence

---

## Real-Time Database

The Realtime Database stores all runtime information required by the controller and mobile application.

Typical information includes:

- Device configuration
- Relay configuration
- Relay states
- Device heartbeat
- Online status
- System commands
- Relay timers
- Device metadata

Whenever the mobile application changes a relay state or configuration, the update is written to Firebase.

The ESP32 continuously monitors the database for changes, executes the requested operation, and immediately reports the updated hardware state back to Firebase.

---

## Communication Flow

```
User
 │
 ▼
Flutter Application
 │
 ▼
Firebase SDK
 │
 ▼
Firebase Realtime Database
 │
 ▼
ESP32 Firmware
 │
 ▼
Relay Hardware
```

Hardware status changes follow the same path in reverse, ensuring every connected application remains synchronized in real time.

---

## Authentication

CRANTROL uses Firebase Authentication to secure access to the system.

Authentication responsibilities include:

- User sign-in
- Session management
- Access validation
- Secure database access

Database operations are only permitted for authenticated users according to the configured security rules.

---

## Database Security

The project includes dedicated Firebase security rule files located in the repository:

```
firebase/
├── rtdb_rules.json
└── firestore_rules.txt
```

### Realtime Database Rules

The Realtime Database rules validate:

- Authenticated access
- Device ownership
- Configuration structure
- Relay count limits
- Data integrity
- Field validation

This prevents invalid or unauthorized data from being written to the database.

---

### Firestore Rules

Firestore is currently not used for application data.

The included rules deny all read and write operations, reserving Firestore for future expansion while preventing unintended access.

---

## Real-Time Synchronization

Firebase Realtime Database automatically synchronizes changes between every connected device.

Synchronized information includes:

- Relay states
- Relay timers
- Device configuration
- Device heartbeat
- Online status
- System commands

This allows multiple mobile devices to monitor and control the same controller while always displaying the latest hardware state.

---

## Online Status Monitoring

The ESP32 periodically updates its heartbeat information within Firebase.

The Flutter application uses this information to determine whether the controller is currently online.

The online indicator is derived from multiple runtime conditions, including:

- Active Ethernet connection
- Internet availability
- Successful Firebase communication
- Recent heartbeat updates

This provides a more accurate representation of controller availability than relying solely on network connectivity.

---

## Configuration Storage

Device configuration is stored centrally within Firebase, allowing it to persist across application restarts and controller reboots.

Configuration includes:

- Device information
- Relay names
- GPIO assignments
- Relay operating modes
- Pulse durations
- User-defined settings

Since the configuration resides in Firebase, all authenticated mobile applications automatically receive the latest configuration without requiring manual synchronization.

---

## Advantages of the Cloud Architecture

Using Firebase provides several benefits:

- Remote access from anywhere
- Automatic real-time synchronization
- Cross-device consistency
- Secure authentication
- Scalable cloud infrastructure
- Persistent configuration storage
- Low-latency state updates
- Minimal application-side networking complexity

---

## Design Principles

The CRANTROL cloud backend has been designed around the following principles:

- Real-time synchronization
- Secure authenticated access
- Reliable cloud communication
- Persistent device configuration
- Scalable architecture
- Modular integration with firmware and mobile application
- Consistent state across all connected clients

---

Firebase forms the communication backbone of CRANTROL, enabling reliable, secure, and synchronized interaction between the Flutter application and the ESP32 controller while providing a scalable foundation for future expansion.

---


## Relay Control System

The relay control system is the primary hardware interface of CRANTROL, enabling the ESP32-S3 to control external electrical devices through independent relay outputs. Every relay operation—from a user pressing a button in the Flutter application to the physical switching of a relay—is coordinated through a synchronized command pipeline that ensures reliable execution and real-time feedback.

The current firmware supports **10 configurable relay channels** by default. Each relay operates independently and can be configured with its own GPIO pin, operating mode, pulse duration, and display name. The architecture has been designed to scale beyond ten relays with minimal firmware modifications.

---

## Relay System Overview

| Property | Value |
|----------|-------|
| Default Relay Count | 10 |
| Expandable | Yes |
| Individual GPIO Mapping | Yes |
| Pulse Mode Support | Yes |
| Latched Mode Support | Yes |
| Active High / Active Low | Supported |
| Real-Time Synchronization | Firebase Realtime Database |
| Runtime State Tracking | Yes |
| Command Revision Protection | Yes |

---

## Relay Architecture

```
                 Relay Control Flow

         Flutter Mobile Application
                    │
                    ▼
      Firebase Realtime Database
                    │
                    ▼
           Firebase Client
                    │
                    ▼
            Relay Manager
                    │
      ┌─────────────┼─────────────┐
      ▼             ▼             ▼
 GPIO Output    Pulse Timer   Runtime State
      │
      ▼
 Physical Relay
      │
      ▼
 Connected Device
```

Every relay operation is processed through the Relay Manager before reaching the physical GPIO output.

---

## Relay Manager

**Primary Files**

```
esp32_firmware/include/relay_manager.h
esp32_firmware/src/relay_manager.cpp
```

The Relay Manager is responsible for every relay-related operation within the firmware.

Responsibilities include:

- Relay initialization
- GPIO output management
- Command execution
- Pulse timing
- Runtime state tracking
- Command deduplication
- Relay state synchronization
- Configuration management

All relay operations pass through this module before interacting with the hardware.

---

## Default Relay Configuration

CRANTROL initializes ten relay slots with predefined names and GPIO assignments.

| Relay | Default Name | GPIO | Default Mode |
|-------:|--------------|-----:|--------------|
| 1 | PC Power | GPIO 21 | 350 ms Pulse |
| 2 | Monitor 1 | GPIO 17 | Latched |
| 3 | Monitor 2 | GPIO 16 | Latched |
| 4 | Motherboard Power Button | GPIO 18 | 250 ms Pulse |
| 5 | Relay 5 | GPIO 15 | Latched |
| 6 | Relay 6 | GPIO 3 | Latched |
| 7 | Relay 7 | GPIO 2 | Latched |
| 8 | Relay 8 | GPIO 1 | Latched |
| 9 | Power | GPIO 0 | 4000 ms Pulse |
| 10 | Reset | GPIO 44 | 1000 ms Pulse |

These defaults provide a practical starting point while remaining fully configurable.

---

## Relay Configuration

Each relay maintains its own configuration object containing:

- Relay ID
- Display name
- GPIO pin
- Enabled/disabled state
- Active High / Active Low configuration
- Pulse duration
- Operating mode
- Current state

This configuration allows each relay to operate independently while remaining synchronized with Firebase and the Flutter application.

---

## Relay Operating Modes

### Latched Mode

In latched mode, the relay remains in its current state until another command changes it.

Typical use cases include:

- Monitors
- Speakers
- Routers
- Network switches
- Lighting
- Power distribution

```
ON  ────────────────► Relay stays ON

OFF ───────────────► Relay stays OFF
```

---

### Pulse Mode

Pulse mode automatically returns the relay to its previous state after a predefined duration.

This mode is commonly used for momentary switches.

Examples include:

- PC Power button
- Motherboard Reset button
- Garage door controllers
- Electronic locks
- Momentary control circuits

```
ON Command

Relay ON
     │
     │ Pulse Timer
     ▼
Relay OFF
```

Pulse duration is configurable for each relay independently.

---

## Command Processing

When a relay command is received, the firmware follows a defined execution sequence.

```
Receive Command
       │
       ▼
Validate Relay
       │
       ▼
Check Revision
       │
       ▼
Execute Command
       │
       ▼
Update Runtime State
       │
       ▼
Trigger Feedback
       │
       ▼
Synchronize Firebase
```

This ensures that relay operations are performed consistently and reflected across all connected clients.

---

## Command Revision Protection

Every relay command includes a unique revision identifier.

Before executing a command, the firmware verifies whether the revision has already been processed.

If the revision matches the previously executed command, the command is ignored.

This mechanism prevents duplicate execution caused by:

- Network retries
- Firebase re-synchronization
- Reconnection events
- Delayed updates

As a result, each command is executed only once.

---

## Runtime State Management

The firmware maintains a runtime state for every relay, including:

- Current ON/OFF state
- Last executed command
- Last command revision
- Last command timestamp
- Active pulse timer

This information is used internally by the firmware and synchronized with Firebase to keep the mobile application up to date.

---

## Pulse Timer Management

Pulse operations are managed using non-blocking timers.

Each relay maintains its own timer, allowing multiple pulse operations to run simultaneously without interrupting the firmware's main execution loop.

Benefits include:

- No blocking delays
- Independent relay timing
- Responsive user interface
- Continuous network communication
- Reliable command execution

---

## Firebase Synchronization

Relay states remain synchronized between the ESP32 and every connected mobile application.

Whenever a relay changes state:

1. The command is received from Firebase.
2. The Relay Manager executes the operation.
3. The runtime state is updated.
4. The latest state is written back to Firebase.
5. All connected clients immediately receive the update.

This ensures consistent relay status across all devices.

---

## Expandability

The relay subsystem has been designed with scalability in mind.

Adding additional relay channels typically requires:

- Increasing the maximum relay count.
- Defining new relay configurations.
- Assigning additional GPIO pins.
- Updating the user interface to display the new channels.

The underlying relay management logic remains unchanged, allowing the system to grow without architectural redesign.

---

## Design Principles

The relay control system follows several key principles:

- Modular relay abstraction
- Independent relay configuration
- Non-blocking execution
- Reliable command processing
- Real-time synchronization
- Duplicate command protection
- Scalable architecture
- Hardware abstraction
- Maintainable implementation

---

The relay control system forms the operational core of CRANTROL, translating user commands into reliable hardware actions while maintaining synchronized state across the ESP32 firmware, Firebase backend, and Flutter mobile application.

---


## Ethernet Communication

CRANTROL uses a **W5500 SPI Ethernet controller** as its primary communication interface, providing a reliable and stable wired network connection between the ESP32-S3 controller and Firebase Realtime Database.

Unlike Wi-Fi-based IoT devices that may experience signal fluctuations or roaming interruptions, CRANTROL is designed to operate over Ethernet for continuous, low-latency communication. Wi-Fi is only enabled temporarily during device provisioning through the captive portal and is not used for normal operation.

The Ethernet subsystem continuously monitors cable status, IP assignment, internet availability, and Firebase connectivity to ensure the controller always reports an accurate connection state.

---

## Communication Overview

| Property | Value |
|----------|-------|
| Network Interface | W5500 Ethernet Controller |
| Communication Bus | SPI (HSPI) |
| Primary Protocol | TCP/IP |
| Cloud Backend | Firebase Realtime Database |
| Connection Type | Wired Ethernet |
| Automatic Reconnection | Yes |
| Internet Verification | Yes |
| Link Monitoring | Continuous |
| Captive Portal | Wi-Fi (Configuration Only) |

---

## Hardware Interface

The W5500 Ethernet controller is connected to the ESP32-S3 through the HSPI bus.

### SPI Pin Assignment

| Signal | GPIO |
|---------|-----:|
| MISO | GPIO 12 |
| MOSI | GPIO 11 |
| SCLK | GPIO 13 |
| CS | GPIO 14 |
| IRQ | GPIO 10 |
| RESET | GPIO 9 |

These assignments are defined centrally within the firmware configuration and used during Ethernet initialization.

---

## Communication Architecture

```
                  Internet

                      │
                      ▼
              Network Router
                      │
                 Ethernet Cable
                      │
                      ▼
              W5500 Ethernet
                      │
                 SPI Interface
                      │
                      ▼
                  ESP32-S3
                      │
          Firebase Client Module
                      │
                      ▼
       Firebase Realtime Database
                      ▲
                      │
              Flutter Application
```

All relay commands and status updates flow through this communication path.

---

## Ethernet Initialization

During startup, the firmware performs the following sequence:

```
Power On
    │
    ▼
Initialize SPI Bus
    │
    ▼
Initialize W5500
    │
    ▼
Register Network Events
    │
    ▼
Wait for Ethernet Link
    │
    ▼
Obtain IP Address
    │
    ▼
Verify Internet Access
    │
    ▼
Connect to Firebase
```

Only after a successful internet connection is established does the firmware begin synchronizing with Firebase.

---

## Connection State Detection

The Ethernet manager continuously monitors multiple connection states rather than relying on cable detection alone.

The firmware distinguishes between:

| Status | Description |
|--------|-------------|
| Cable Unplugged | No physical Ethernet connection detected |
| Connected, No IP | Cable connected but IP address not yet assigned |
| Connected, No Internet | IP address available but internet unreachable |
| Connected | Ethernet, internet, and Firebase operational |

This layered approach provides a more accurate representation of device connectivity.

---

## Internet Verification

Obtaining an IP address does not necessarily indicate internet availability.

After a valid IP address is assigned, the firmware performs periodic internet connectivity checks before marking the controller as fully online.

The verification process ensures:

- Ethernet cable is connected
- Valid IP address has been assigned
- Internet is reachable
- Cloud communication is possible

Only when all conditions are satisfied is the controller considered online.

---

## Network Monitoring

The Ethernet manager continuously monitors:

- Physical cable connection
- IP address assignment
- Internet availability
- Firebase communication
- Network recovery events

If any of these conditions change, the firmware immediately updates its internal network state and synchronizes the new status with Firebase.

---

## Automatic Recovery

The communication subsystem has been designed to recover automatically from common network interruptions.

Recovery events include:

- Ethernet cable unplugged
- Ethernet cable reconnected
- Router restart
- DHCP lease renewal
- Temporary internet outage
- Firebase reconnection

The firmware periodically retries failed connections without requiring a manual reboot.

---

## Online Status Synchronization

The controller periodically updates its heartbeat information in Firebase.

The Flutter application determines the device's online status using multiple conditions, including:

- Ethernet link status
- Internet connectivity
- Successful Firebase communication
- Recent heartbeat updates

This prevents false online indications caused by stale heartbeat data or temporary network interruptions.

---

## Communication Flow

```
Flutter App
      │
      ▼
Firebase Command
      │
      ▼
ESP32 Firebase Client
      │
      ▼
Ethernet Manager
      │
      ▼
Relay Manager
      │
      ▼
Relay Hardware

          ▲
          │
    Status Feedback
          │
          ▼
Firebase Realtime Database
          │
          ▼
Flutter Application
```

Every relay operation and device status update follows this synchronized communication path.

---

## Captive Portal Integration

While Ethernet is the primary communication interface, the firmware also includes a Wi-Fi-based captive portal for device provisioning.

The captive portal is used exclusively for:

- Initial device setup
- Updating network configuration
- Configuring Firebase settings
- Device recovery

Once configuration is complete, the controller resumes normal Ethernet-based operation.

---

## Design Principles

The Ethernet communication subsystem has been designed around the following principles:

- Reliable wired connectivity
- Automatic connection recovery
- Continuous network monitoring
- Real-time cloud synchronization
- Accurate online/offline detection
- Modular communication architecture
- Non-blocking operation
- Minimal communication latency

---

The Ethernet communication subsystem provides the networking foundation of CRANTROL, ensuring stable and continuous communication between the ESP32-S3 controller, Firebase cloud backend, and Flutter mobile application while maintaining reliable real-time synchronization.

---


## Captive Portal Configuration

CRANTROL includes an integrated captive portal that provides a browser-based interface for configuring the controller without requiring firmware recompilation or serial communication.

The captive portal operates independently of the Flutter application and is intended for initial device provisioning, network configuration, relay setup, and system maintenance. When activated, the ESP32-S3 creates a temporary Wi-Fi Access Point and hosts a lightweight web application that allows configuration directly from any modern web browser.

After configuration is complete, all settings are stored in the ESP32's Non-Volatile Storage (NVS), allowing them to persist across power cycles and firmware restarts.

---

## Overview

| Property | Description |
|----------|-------------|
| Implementation | Embedded Web Server |
| HTTP Server | WebServer |
| DNS Server | DNSServer |
| Wi-Fi Mode | Access Point (AP) |
| Configuration Storage | ESP32 NVS (Preferences) |
| Authentication | Login Required |
| Configuration Method | Browser-Based |
| Runtime Dependency | Independent of Flutter App |

---

## Purpose

The captive portal provides a local configuration interface for situations where the mobile application cannot yet communicate with the controller.

Typical use cases include:

- Initial controller setup
- Device provisioning
- Firebase configuration
- Device identification
- Relay configuration
- Network configuration
- System maintenance
- Device recovery

The portal eliminates the need to modify firmware source code whenever configuration values change.

---

## Architecture

```
           Smartphone / Laptop
                    │
            Connect via Wi-Fi
                    │
                    ▼
          ESP32-S3 Access Point
                    │
             Embedded DNS Server
                    │
                    ▼
           Embedded Web Server
                    │
      ┌─────────────┼─────────────┐
      ▼             ▼             ▼
    Login      Dashboard      Settings
                    │
                    ▼
          Configuration Manager
                    │
                    ▼
          ESP32 NVS (Preferences)
```

---

## Firmware Components

The captive portal is implemented as a dedicated firmware module.

### Primary Files

```
esp32_firmware/include/captive_portal.h
esp32_firmware/src/captive_portal.cpp
```

The module is initialized during firmware startup and interacts with the following subsystems:

- Relay Manager
- Firebase Client
- Configuration Manager
- Runtime State
- Non-Volatile Storage (NVS)

---

## Web Server

The embedded HTTP server is responsible for serving the entire configuration interface.

Registered routes include:

| Route | Purpose |
|--------|---------|
| `/` | Login page |
| `/login` | User authentication |
| `/dashboard` | Main dashboard |
| `/settings` | Device configuration |
| `/api/status` | Runtime status API |
| `/api/config` | Current configuration |
| `/api/save-settings` | Save device settings |
| `/api/save-relays` | Save relay configuration |
| `/api/control-relay` | Relay control API |
| `/restart` | Restart controller |
| `/logout` | End authenticated session |

Unknown requests are redirected to the portal entry page.

---

## Authentication

Before configuration pages become accessible, users must authenticate through the portal's login interface.

After successful authentication:

- An authenticated session is established
- Configuration pages become accessible
- Relay control endpoints are enabled
- Settings may be modified and saved

Protected API endpoints reject unauthenticated requests.

---

## Dashboard

The dashboard provides an overview of the controller's current runtime state.

Information includes:

- Device status
- Relay status
- Network status
- Runtime information
- Configuration summary

This allows administrators to verify controller operation without using the mobile application.

---

## Configuration Management

The portal allows configuration of multiple system parameters.

### Device Configuration

- Device name
- Device ID
- Room ID
- Room code

---

### Network Configuration

- Access Point name
- Access Point password

---

### Firebase Configuration

The portal supports updating Firebase-related configuration, including:

- API Key
- Authentication Domain
- Database URL
- Project ID
- Storage Bucket
- Messaging Sender ID
- Application ID
- Authentication Email
- Authentication Password

These values are loaded into the firmware configuration and persisted after saving.

---

### Relay Configuration

Each relay can be configured independently.

Available settings include:

- Relay name
- GPIO assignment
- Operating mode
- Pulse duration
- Enable/disable state
- Active High / Active Low configuration

The portal supports configuration for every relay managed by the firmware.

---

## Configuration Storage

When settings are saved, the firmware writes the updated configuration to ESP32 Non-Volatile Storage (NVS).

Persisted information includes:

- Device information
- Network configuration
- Firebase configuration
- Relay configuration
- User-defined settings

Because the configuration is stored in NVS, it remains available after power loss or controller reboot.

---

## Runtime Integration

The captive portal communicates directly with the firmware runtime.

Configuration updates immediately affect:

- Runtime configuration
- Relay Manager
- Firebase Client
- Device metadata

Some configuration changes may require a firmware restart before taking effect.

---

## DNS Redirection

The integrated DNS server redirects client requests to the local web interface while connected to the Access Point.

This allows users to open any website address and automatically arrive at the configuration portal, providing a captive portal experience similar to common network devices.

---

## Controller Restart

After saving configuration changes, the portal can restart the controller to ensure updated settings are applied consistently.

The restart process preserves all configuration previously written to NVS.

---

## Design Principles

The captive portal has been developed around the following principles:

- Standalone configuration
- Browser-based management
- Persistent configuration storage
- Secure authenticated access
- Modular firmware integration
- No firmware recompilation for configuration changes
- Independent operation from the mobile application
- Simplified device provisioning

---

The captive portal provides a self-contained configuration interface that enables administrators to provision, configure, and maintain CRANTROL controllers directly from a web browser while ensuring all settings remain synchronized with the firmware's persistent configuration storage.

---
