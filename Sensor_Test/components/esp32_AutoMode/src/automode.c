#include "automode.h"
#include "pump.h"
#include "water_sensor.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include <stdio.h> 

#define AUTO_MODE_COOLDOWN_MS  (5000)

static const char *TAG = "AUTO MODE";
static TaskHandle_t xAutoTaskHandle = NULL;
bool is_running() {
    return (xAutoTaskHandle != NULL);
}

void vAutoModeTask(void *pvParameters) {
    ESP_LOGI(TAG, "AUTO MODE TASK");
    /*Pumping*/
    pump_start();
    vTaskDelay(pdMS_TO_TICKS(100));
    
    /*Set time limit*/
    TickType_t xStartTime = xTaskGetTickCount();
    const TickType_t xMaxRunTime = pdMS_TO_TICKS(10000);    //10s

    /*Checking*/
    while(1) {
        if(gpio_get_level(GPIO_NUM_17) == 0) {
            ESP_LOGW(TAG, "SWITCH TURNED OFF - STOPPING");
            break; 
        }
        /*Check water level*/
        float cur_water_level = water_sensor_read_level();
        if(cur_water_level < 10.0f) break;
        /*Check time limit*/
        if ((xTaskGetTickCount() - xStartTime) >= xMaxRunTime) {
            ESP_LOGW(TAG, "TIME OUT, STOP PUMPING");
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
    
    /*End of mode*/
    pump_stop();
    ESP_LOGI(TAG, "COMPLETED");
    vTaskDelay(pdMS_TO_TICKS(AUTO_MODE_COOLDOWN_MS));   //rest time
    xAutoTaskHandle = NULL;
    vTaskDelete(NULL);
}

void auto_start() {
    if(xAutoTaskHandle == NULL) {
        xTaskCreate(vAutoModeTask, "AutoModeTask", 2048, NULL, 5, &xAutoTaskHandle);
    }
}
void auto_stop() {
    if(xAutoTaskHandle != NULL) {
        vTaskDelete(xAutoTaskHandle);
        xAutoTaskHandle = NULL;
    }
    pump_stop();
}