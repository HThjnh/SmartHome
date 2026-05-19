# 🏠 SmartHome - Automated Roof Cooling System
An automated SmartHome system designed to monitor and control a water-sprinkling cooling system for roofs based on real-time environmental data. The project integrates hardware nodes (ESP32/NodeMCU) with a cross-platform mobile application to maximize cooling efficiency and optimize energy consumption.
## 🚀 Key Features
* **Real-time Monitoring:** Continuous tracking of roof temperature and humidity levels.
* **Intelligent Pump Control:**
    * **Automated Threshold (temp > 40):** Switches directly to **Auto Mode**, instantly activating the water pump for emergency cooling without requiring user intervention.
* **Cross-Platform Mobile App (Flutter):** Provides an intuitive dashboard UI to view live data, receive instant warning alerts, and seamlessly toggle between Manual and Auto modes.
* **Secure Configuration:** Features a robust configuration setup for secure communication across NodeMCU/ESP32 hardware nodes.

---

## 🛠️ System Architecture

### 1. Hardware Components
* **Microcontroller:** ESP32 / NodeMCU (Configured via ESP-IDF / CMake).
* **Sensors:** DS18B20 (Temperature & Humidity sensing).
* **Actuators:** Relay module controlling a 12V water pump.

### 2. Software & Platforms
* **Firmware:** C/C++ (ESP-IDF Framework / CMake).
* **Mobile App:** Flutter (Cross-platform for iOS & Android).
* **Protocols:** MQTT / HTTP REST API.

## 🛠️ Setup & Installation

### 1. Flashing the Firmware
Ensure you have the **ESP-IDF toolchain** (or the ESP-IDF VS Code Extension) installed before building the project.

```bash
# Apply secure configuration setup for the hardware node
cp sdkconfig.ci sdkconfig

# Build the project
idf.py build

# Flash the firmware and open the serial monitor
idf.py -p <PORT> flash monitor
