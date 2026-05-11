#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "esp_log.h"
#include "mqtt_client.h"
#include "controlmode.h"

#include "pump.h"
#include "relay.h"
#include "water_sensor.h"
#include "ds18b20.h"
#include "wifi_sta.h"

#define TOPIC_PUMP_CONTROL   "home/roof/pump_control"
#define TOPIC_PUMP_STATUS    "home/roof/pump_status"

#define TOPIC_MODE_CONTROL   "home/roof/mode_control"
#define TOPIC_MODE_STATUS    "home/roof/system_mode"

#define TOPIC_LED_CONTROL    "home/led/control"
#define TOPIC_LED_STATUS     "home/led/status"

#define TOPIC_WATER_LEVEL    "home/roof/water_level"

#define LED_LIVING  5
#define LED_BED     6
#define LED_KITCHEN 7

static const char *TAG = "CONTROL MODE";
static esp_mqtt_client_handle_t client;

extern system_mode_t current_mode;
extern const uint8_t isrgrootx1_pem_start[] asm("_binary_isrgrootx1_pem_start");
extern const uint8_t isrgrootx1_pem_end[]   asm("_binary_isrgrootx1_pem_end");

static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    ESP_LOGD(TAG, "Event dispatched from event loop base=%s, event_id=%" PRIi32, base, event_id);
    esp_mqtt_event_handle_t event = event_data;
    esp_mqtt_client_handle_t client = event->client;

    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");
        esp_mqtt_client_subscribe(client, TOPIC_PUMP_CONTROL, 1);
        esp_mqtt_client_subscribe(client, TOPIC_MODE_CONTROL, 1);
        esp_mqtt_client_subscribe(client, TOPIC_LED_CONTROL, 1);
        
        publish_pump_status(pump_status());
        publish_system_mode(current_mode);
        break;

    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGI(TAG, "MQTT_EVENT_DISCONNECTED");
        break;

    case MQTT_EVENT_UNSUBSCRIBED:
        ESP_LOGI(TAG, "MQTT_EVENT_UNSUBSCRIBED, msg_id=%d", event->msg_id);
        break;

    case MQTT_EVENT_PUBLISHED:
        ESP_LOGI(TAG, "MQTT_EVENT_PUBLISHED, msg_id=%d", event->msg_id);
        break;

    /*Main LOGIC*/
    case MQTT_EVENT_DATA:
        ESP_LOGI(TAG, "MQTT_EVENT_DATA");
        char data_str[32];
        int len = (event->data_len < sizeof(data_str) - 1) ? event->data_len : sizeof(data_str) - 1;
        memcpy(data_str, event->data, len);
        data_str[len] = '\0';

        //1. Control mode
        if(strncmp(event->topic, TOPIC_MODE_CONTROL, event->topic_len) == 0) {
            if(strcmp(data_str, "MANUAL") == 0) {
                current_mode = SYSTEM_MODE_MANUAL;
            }
            else if(strcmp(data_str, "AUTO") == 0) {
                current_mode = SYSTEM_MODE_AUTO;
            }
            publish_system_mode(current_mode);
        }
        //2. Control pump
        else if(strncmp(event->topic, TOPIC_PUMP_CONTROL, event->topic_len) == 0) {
            current_mode = SYSTEM_MODE_MANUAL;

            if(strcmp(data_str, "OFF") == 0) {
                ESP_LOGI(TAG, "User turned OFF");
                pump_stop();
                publish_pump_status(false);
            }
            else if(strcmp(data_str, "ON") == 0) {
                ESP_LOGI(TAG, "User turned ON");
                pump_start();
                publish_pump_status(true);
            }
            //Update on App
            publish_system_mode(current_mode);
        }
        //3. Control led
        else if(strncmp(event->topic, TOPIC_LED_CONTROL, event->topic_len) == 0) {
            //Turn on/off LIVING LED
            if(strcmp(data_str, "LIVING_ON") == 0) {
                gpio_set_level(LED_LIVING, 1);
                publish_led_status("LIVING", true);
            }
            else if(strcmp(data_str, "LIVING_OFF") == 0) {
                gpio_set_level(LED_LIVING, 0);
                publish_led_status("LIVING", false);
            }
            //Turn on/off BED LED
            else if(strcmp(data_str, "BED_ON") == 0) {
                gpio_set_level(LED_BED, 1);
                publish_led_status("BED", true);
            }
            else if(strcmp(data_str, "BED_OFF") == 0) {
                gpio_set_level(LED_BED, 0);
                publish_led_status("BED", false);
            }
            //Turn on/off KITCHEN LED
            else if(strcmp(data_str, "KITCHEN_ON") == 0) {
                gpio_set_level(LED_KITCHEN, 1);
                publish_led_status("KITCHEN", true);
            }
            else if(strcmp(data_str, "KITCHEN_OFF") == 0) {
                gpio_set_level(LED_KITCHEN, 0);
                publish_led_status("KITCHEN", false);
            }
        }
        break;

    case MQTT_EVENT_ERROR:
        ESP_LOGI(TAG, "MQTT_EVENT_ERROR");
        if (event->error_handle->error_type == MQTT_ERROR_TYPE_TCP_TRANSPORT) {
            ESP_LOGI(TAG, "Last error code reported from esp-tls: 0x%x", event->error_handle->esp_tls_last_esp_err);
            ESP_LOGI(TAG, "Last tls stack error number: 0x%x", event->error_handle->esp_tls_stack_err);
            ESP_LOGI(TAG, "Last captured errno : %d (%s)",  event->error_handle->esp_transport_sock_errno, strerror(event->error_handle->esp_transport_sock_errno));
        } 
        else if (event->error_handle->error_type == MQTT_ERROR_TYPE_CONNECTION_REFUSED) {
            ESP_LOGI(TAG, "Connection refused error: 0x%x", event->error_handle->connect_return_code);
        } 
        else {
            ESP_LOGW(TAG, "Unknown error type: 0x%x", event->error_handle->error_type);
        }
        break;
    default:
        ESP_LOGI(TAG, "Other event id:%d", event->event_id);
        break;
    }
}

esp_err_t control_mode_init(void) {
    const esp_mqtt_client_config_t mqtt_cfg = {
        .broker = {
            .address = {
                .uri = "mqtts://684def09438e405290520560dfa5acc9.s1.eu.hivemq.cloud",
                .port = 8883,
            },
            .verification.certificate = (const char *)isrgrootx1_pem_start
        },
        .credentials = {
            .username = "Basys",
            .authentication.password = "Basys1234"
        }
    };

    client = esp_mqtt_client_init(&mqtt_cfg);
    if(client == NULL) {
        return ESP_FAIL;
    }
    /* The last argument may be used to pass data to the event handler, in this example mqtt_event_handler */
    esp_err_t err = esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    if(err != ESP_OK) return err;

    err = esp_mqtt_client_start(client);
    return err;
}

esp_err_t publish_temp(const char *topic, float temp) {
    if(client == NULL) return ESP_FAIL;
    char temp_str[16];
    snprintf(temp_str, sizeof(temp_str), "%.2f", temp);

    int msg_id = esp_mqtt_client_publish(client, topic, temp_str, 0, 1, 1);
    if(msg_id != -1) {
        ESP_LOGI("MQTT_PUB", "Published Temp: %s to topic: %s", temp_str, topic);
        return ESP_OK;
    }
    else {
        ESP_LOGE("MQTT_PUB", "Failed to publish temp");
        return ESP_FAIL;
    }
}

esp_err_t publish_water_status(float water_level) {
    if(client == NULL) return ESP_FAIL;
    char water_str[16];
    snprintf(water_str, sizeof(water_str), "%.1f", water_level);

    int msg_id = esp_mqtt_client_publish(client, "home/roof/water_level", water_str, 0, 1, 1);
    if(msg_id != -1) {
        ESP_LOGI("MQTT_PUB", "Published Water level: %s to topic: home/roof/water_level", water_str);
        return ESP_OK;
    }
    else {
        ESP_LOGE("MQTT_PUB", "Failed to publish water level");
        return ESP_FAIL;
    }
}

esp_err_t publish_pump_status(bool is_on) {
    if (client == NULL) return ESP_FAIL;
    const char *status_str = is_on ? "ON" : "OFF";

    int msg_id = esp_mqtt_client_publish(client, "home/roof/pump_status", status_str, 0, 1, 1);
    if (msg_id != -1) {
        ESP_LOGI("MQTT_PUB", "Pump status published: %s", status_str);
        return ESP_OK;
    } 
    else {
        ESP_LOGE("MQTT_PUB", "Failed to publish pump status");
        return ESP_FAIL;
    }
}

esp_err_t publish_system_mode(system_mode_t mode) {
    if (client == NULL) return ESP_FAIL;
    const char *mode_str = (mode == SYSTEM_MODE_AUTO) ? "AUTO" : "MANUAL";

    int msg_id = esp_mqtt_client_publish(client, "home/roof/system_mode", mode_str, 0, 1, 1);
    if (msg_id != -1) {
        ESP_LOGI("MQTT_PUB", "System mode published: %s", mode_str);
        return ESP_OK;
    } 
    else {
        ESP_LOGE("MQTT_PUB", "Failed to publish system mode");
        return ESP_FAIL;
    }
}

esp_err_t publish_led_status(const char* room, bool is_on) {
    if (client == NULL) return ESP_FAIL;
    char status_msg[32];
    snprintf(status_msg, sizeof(status_msg), "%s_%s", room, is_on ? "ON" : "OFF");
    return (esp_mqtt_client_publish(client, TOPIC_LED_STATUS, status_msg, 0, 1, 1) != -1) ? ESP_OK : ESP_FAIL;
}