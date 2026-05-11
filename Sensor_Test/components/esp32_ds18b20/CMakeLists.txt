idf_component_register(SRCS "ds18b20.c"
                       INCLUDE_DIRS "include"
                       REQUIRES driver esp_timer
                       PRIV_REQUIRES esp32_owb)
