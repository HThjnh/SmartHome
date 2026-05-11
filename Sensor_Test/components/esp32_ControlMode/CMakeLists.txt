idf_component_register(
    SRCS "controlmode.c"
    INCLUDE_DIRS "inc"
    REQUIRES mqtt wifi_sta pump water_sensor esp32_ds18b20 esp32_owb
)

target_add_binary_data(${COMPONENT_LIB} "isrgrootx1.pem" TEXT)