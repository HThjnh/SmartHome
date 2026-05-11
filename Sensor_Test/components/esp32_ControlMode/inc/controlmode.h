#ifndef CONTROL_MODE_H
#define CONTROL_MODE_H

#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

//Define mode
typedef enum {
    SYSTEM_MODE_MANUAL = 0,
    SYSTEM_MODE_AUTO = 1
} system_mode_t;
/**
 * @brief Initialize system, which controls MQTT 
 * Set up SSL, connect to HiveMQTT
 * @return esp_err_t ESP_OK if success
 */
esp_err_t control_mode_init(void);

/**
 * @brief Send temp data to Broker HiveMQ
 * Read data form DS18B20 sensor
 * @return esp_err_t ESP_OK if success
 */
esp_err_t publish_temp(const char *topic, float temp);

/**
 * @brief Send water level data to Broker HiveMQ
 * Read data from water sensor
 * @return esp_err_t ESP_OK if success
 */
esp_err_t publish_water_status(float water_level);

/**
 * Send pump status to Broker HiveMQ
 */
esp_err_t publish_pump_status(bool is_on);

/**
 * @brief Send current mode to Broker
 * Help interface synchronization
 */
esp_err_t publish_system_mode(system_mode_t mode);

/**
 * @brief Send status of LED to broker
 */
esp_err_t publish_led_status(const char* room, bool is_on);

#endif /*CONTROL_MODE_H*/
