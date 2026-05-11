#include "water_sensor.h"
#include <stdio.h>
#include "esp_log.h"
#include "esp_adc/adc_oneshot.h"
static const char *TAG = "Water Sensor";
static adc_oneshot_unit_handle_t adc1_handle;
static bool is_initialized = false;

esp_err_t water_sensor_init(void) {
    //Set up ADC
    adc_oneshot_unit_init_cfg_t init_config1 = {
        .unit_id = ADC_UNIT_1,
        .ulp_mode = ADC_ULP_MODE_DISABLE,
    };
    esp_err_t ret = adc_oneshot_new_unit(&init_config1, &adc1_handle);
    
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize ADC!");
        return ret;
    }

    //Set up channel for GPIO
    adc_oneshot_chan_cfg_t config = {
        .bitwidth = ADC_BITWIDTH_DEFAULT, // 12-bit (0-4095)
        .atten = ADC_ATTEN_DB_12,         // ~3.3V
    };
    ret = adc_oneshot_config_channel(adc1_handle, WATER_LEVEL_ADC_CHANNEL, &config);
    
    if (ret == ESP_OK) {
        is_initialized = true;
        ESP_LOGI(TAG, "Initialize completed (GPIO34)");
    } else {
        ESP_LOGE(TAG, "Channel set up fail!");
    }

    return ret;
}

float water_sensor_read_level(void) {
    if (!is_initialized) {
        ESP_LOGW(TAG, "Water Sensor has not been initialized!");
        return -1.0f;
    }

    int raw_val = 0;
    //Read value from potentionmeter (simulate water sensor)
    esp_err_t ret = adc_oneshot_read(adc1_handle, WATER_LEVEL_ADC_CHANNEL, &raw_val);

    if (ret == ESP_OK) {
        // Conversion 
        // Calculate: (value / 4095) * 100
        float percentage = ((float)raw_val / 4095.0f) * 100.0f;
        return percentage;
    } else {
        ESP_LOGE(TAG, "ADC value reading error!");
        return -1.0f; 
    }
}