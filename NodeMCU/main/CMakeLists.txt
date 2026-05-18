idf_component_register(SRCS "MCU.c"
         INCLUDE_DIRS "."
                    PRIV_REQUIRES mqtt nvs_flash esp_netif esp_event wifi_sta esp32_ControlMode esp32_AutoMode pump water_sensor esp32_owb esp32_ds18b20  esp_driver_gpio spi_flash)           
