#ifndef WATER_SENSOR_H
#define WATER_SENSOR_H

#include "esp_err.h"
#include "hal/adc_types.h"
#define WATER_LEVEL_ADC_CHANNEL ADC_CHANNEL_6       //GPIO34 (ADC1)

/**
 * Initialization ADC to read water level value
 * @return ESP_OK if complete
 * @return -1 if error
 */
esp_err_t water_sensor_init(void);

/**
 * @brief read water level value
 * @return value
 * @return -1 if error
 */
float water_sensor_read_level(void);

#endif