#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "driver/gpio.h"
#include "esp_log.h"
#include "nvs_flash.h"         // Cho nvs_flash_init, nvs_flash_erase
#include "esp_netif.h"         // Cho esp_netif_init
#include "esp_event.h"         // Cho esp_event_loop_create_default

#include "wifi_sta.h"  
#include "ds18b20.h"
#include "water_sensor.h"
#include "pump.h"
#include "relay.h"
#include "automode.h"
#include "controlmode.h"

//Cooling system

#define RELAY_GPIO_PIN    18
#define SWITCH_GPIO_CHECK GPIO_NUM_17
#define GPIO_DS18B20_PIN  32

//LED control system
#define LED_LIVING  25
#define LED_BED     26
#define LED_KITCHEN 27
#define PHYSICAL_LED_LIVING  35
#define PHYSICAL_LED_BED     36
#define PHYSICAL_LED_KITCHEN 39

#define TOPIC_LED_CONTROL    "home/led/control"
#define TOPIC_LED_STATUS     "home/led/status"
#define TEMP_DASHBOARD       "home/roof/temp/dashboard"
#define TEMP_GRAPH           "home/roof/temp/graph"

static const uint64_t connection_timeout_ms = 2000;
static const char *TAG = "MAIN";

esp_err_t esp_ret;
EventGroupHandle_t network_event_group;
system_mode_t current_mode = SYSTEM_MODE_MANUAL;

void init_feedback_system() {
    gpio_config_t io_conf_in = {
        .pin_bit_mask = (1ULL << SWITCH_GPIO_CHECK ) | (1ULL << PHYSICAL_LED_LIVING) | (1ULL << PHYSICAL_LED_BED) | (1ULL << PHYSICAL_LED_KITCHEN),
        .mode = GPIO_MODE_INPUT,
        .pull_down_en = GPIO_PULLDOWN_DISABLE, 
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .intr_type = GPIO_INTR_ANYEDGE
    };
    gpio_config(&io_conf_in);

    gpio_config_t io_conf_out = {
        .pin_bit_mask = (1ULL << LED_LIVING) | (1ULL << LED_BED) | (1ULL << LED_KITCHEN),
        .mode = GPIO_MODE_OUTPUT,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf_out);

    gpio_set_level(RELAY_GPIO_PIN, 0);
    gpio_set_level(LED_LIVING, 0);
    gpio_set_level(LED_BED, 0);
    gpio_set_level(LED_KITCHEN, 0);
}

void MonitorTask(void *pvParameters) {
    DS18B20_Info *ds18b20_info = (DS18B20_Info *)pvParameters;
    float temp;
    system_mode_t last_mode = -1;
    static bool wifi_log = false;
    bool last_pump_physical_status = -1;
    bool last_system_mode = -1;

    static int graph_timer = 0, dashboard_timer = 0;

    while(1) {
        DS18B20_ERROR err = ds18b20_convert_and_read_temp(ds18b20_info, &temp);
        float water_level = water_sensor_read_level();
        bool running = is_running();
        //Read current physical status of pump
        int current_pump_physical_status = gpio_get_level(SWITCH_GPIO_CHECK);
        EventBits_t bits = xEventGroupGetBits(network_event_group);
        bool connected = (bits & WIFI_STA_CONNECTED_BIT);    

        ESP_LOGI(TAG, "Water: %.2f", water_level);
        ESP_LOGE(TAG, "Temp: %.2f", temp);
        //DS18B20 error
        if(err != DS18B20_OK) {
            if(running) auto_stop();
            ESP_LOGE(TAG, "Sensor Error");
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }
        
        //Out of water
        if(water_level < 10.0f) {
            if(running) auto_stop();
            ESP_LOGE(TAG, "STOP, OUT OF WATER!");
            if(connected) publish_water_status(water_level);
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }

        //Connected to WiFi
        if(connected) {
            if(wifi_log) {
                ESP_LOGI(TAG, "WiFi reconnected!");
                wifi_log = false;
                publish_system_mode(current_mode);
            }
            publish_water_status(water_level);

            //Temp Graph
            graph_timer++;
            if(graph_timer >= 30) {
                publish_temp(TEMP_GRAPH, temp);
                graph_timer = 0;
                ESP_LOGI(TAG, "Published temp to history");
            }
            //Temp Dashboard
            dashboard_timer++;
            if(dashboard_timer >= 5) {
                publish_temp(TEMP_DASHBOARD, temp);
                dashboard_timer = 0;
                ESP_LOGI(TAG, "Published temp to dashboard");
            }
            //Send physical status 
            if(current_pump_physical_status != last_pump_physical_status) {
                publish_pump_status(current_pump_physical_status);
                last_pump_physical_status = current_pump_physical_status;
                
                if (current_pump_physical_status == 0 && running == true) {
                    ESP_LOGW(TAG, "Relay ON but Pump OFF (Check Rocker Switch!)");
                }
            }
            //Manual Mode
            if(current_mode == SYSTEM_MODE_MANUAL) {
                if(last_mode != SYSTEM_MODE_MANUAL) {
                    ESP_LOGI(TAG, "START MANUAL MODE");
                    last_mode = SYSTEM_MODE_MANUAL;
                    publish_system_mode(current_mode);
                }
            }
            //Auto Mode
            else if(current_mode == SYSTEM_MODE_AUTO) {
                if(last_mode != SYSTEM_MODE_AUTO) {
                    ESP_LOGI(TAG, "CHANGE TO AUTO MODE");
                    last_mode = SYSTEM_MODE_AUTO;
                    publish_system_mode(current_mode);
                }
                if (temp > 35.0f && !running) auto_start();
                if (temp <= 30.0f && running) auto_stop();
            }
        }
        //Disconnected to WiFi
        else {
            //Auto mode
            if(!wifi_log) {
                // Display notification
                ESP_LOGW(TAG, "WiFi Disconnected");
                wifi_log = true;
            }
            if (temp > 35.0f) {
                if(last_mode != SYSTEM_MODE_AUTO || !running) {
                    ESP_LOGI(TAG, "TEMP > 35°C, START AUTO MODE");
                    auto_start();
                    last_mode = SYSTEM_MODE_AUTO;
                    current_mode = SYSTEM_MODE_MANUAL;
                }
            }
            else{
                if(running) {
                    ESP_LOGI(TAG, "TEMP < 35°C, STOP AUTO MODE");
                    auto_stop();
                }
            }
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
        ESP_LOGI(TAG, "Done Task");
    }
}

void NetworkManagementTask(void *pvParameters) {
    ESP_LOGI("NET", "Waiting connect to WiFi...");
    EventBits_t bits = xEventGroupWaitBits(network_event_group, WIFI_STA_CONNECTED_BIT | WIFI_STA_IPV4_OBTAINED_BIT, pdFALSE, pdTRUE, pdMS_TO_TICKS(connection_timeout_ms));

    if(bits & WIFI_STA_IPV4_OBTAINED_BIT) {
        ESP_LOGI("NET", "Wifi connected, initialize MQTT...");
        control_mode_init();
    }

    vTaskDelete(NULL);
}

void app_main(void) {

    // Initialize NVS: ESP32 WiFi driver uses NVS to store WiFi settings
    // Erase NVS partition if it's out of free space or new version
    esp_ret = nvs_flash_init();
    if (esp_ret == ESP_ERR_NVS_NO_FREE_PAGES || esp_ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
      ESP_ERROR_CHECK(nvs_flash_erase());
      esp_ret = nvs_flash_init();
    }
    if (esp_ret != ESP_OK) {
        ESP_LOGE(TAG, "Error (%d): Failed to initialize NVS", esp_ret);
    }

    // Initialize TCP/IP network interface (only call once in application)
    // Must be called prior to initializing the network driver!
    esp_ret = esp_netif_init();
    if (esp_ret != ESP_OK) {
        ESP_LOGE(TAG, "Error (%d): Failed to initialize network interface", esp_ret);
    }

    // Create default event loop that runs in the background
    // Must be running prior to initializing the network driver!
    esp_ret = esp_event_loop_create_default();
    if (esp_ret != ESP_OK) {
        ESP_LOGE(TAG, "Error (%d): Failed to create default event loop", esp_ret);
    }

    // Initialize event group
    network_event_group = xEventGroupCreate();
    /*DS18B20 Init*/
    static OneWireBus *owb;
    static owb_gpio_driver_info gpio_driver_info;
    owb = owb_gpio_initialize(&gpio_driver_info, GPIO_DS18B20_PIN);
    owb_use_crc(owb, true);  //Turn on CRC for bus 
    DS18B20_Info * ds18b20_info = ds18b20_malloc(); 
    ds18b20_init_solo(ds18b20_info, owb); 
        //Check error 
    ds18b20_use_crc(ds18b20_info, true); 
    ds18b20_set_resolution(ds18b20_info, DS18B20_RESOLUTION_12_BIT);
    /*End of DS18B20 Init*/

    /*Water sensor Init*/
    water_sensor_init();
    /*End of Water sensor Init*/

    /*Relay Init*/
    relay_init();
    /*End of Relay init*/

    /*Pump Init*/
    pump_init();
    /*End of pump init*/

    /*GPIO init*/
    init_feedback_system();

    /*Set up successfully*/
    ESP_LOGI(TAG, "Start...");
    xTaskCreate(MonitorTask, "MonitorTask", 8192, (void *)ds18b20_info, 5, NULL);

    //WiFi event
    EventBits_t network_event_bits;

    // Initialize network connection
    esp_ret = wifi_sta_init(network_event_group);
    if (esp_ret != ESP_OK) {
        ESP_LOGE(TAG, "Error (%d): Failed to initialize WiFi", esp_ret);
    }

    xTaskCreate(NetworkManagementTask, "NetTask", 4096, NULL, 3, NULL);

    ESP_LOGI(TAG, "Waiting for IP address...");
    network_event_bits = xEventGroupWaitBits(network_event_group, WIFI_STA_IPV4_OBTAINED_BIT | WIFI_STA_IPV6_OBTAINED_BIT, pdFALSE, pdTRUE, pdMS_TO_TICKS(connection_timeout_ms));
    if (network_event_bits & WIFI_STA_IPV4_OBTAINED_BIT) {
        ESP_LOGI(TAG, "Connected to IPv4 network");
    } 
    else if (network_event_bits & WIFI_STA_IPV6_OBTAINED_BIT) {
        ESP_LOGI(TAG, "Connected to IPv6 network");
    } 
    else {
        ESP_LOGE(TAG, "Failed to obtain IP address");
    }

}