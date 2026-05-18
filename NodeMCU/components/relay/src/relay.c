#include "relay.h"

void relay_init(void) {
    gpio_config_t io_conf = {
        .pin_bit_mask   = (1ULL << RELAY_GPIO_PIN),
        .mode           = GPIO_MODE_OUTPUT,
        .pull_up_en     = GPIO_PULLUP_DISABLE,
        .pull_down_en   = GPIO_PULLDOWN_DISABLE,
        .intr_type      = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf);
    relay_off();
}
void relay_on(void) {
    gpio_set_level(RELAY_GPIO_PIN, RELAY_ON_LEVEL);
}
void relay_off(void) {
    gpio_set_level(RELAY_GPIO_PIN, RELAY_OFF_LEVEL);
}
void relay_toggle(void) {
    int current_level = gpio_get_level(RELAY_GPIO_PIN);
    gpio_set_level(RELAY_GPIO_PIN, !current_level);
}
bool relay_status(void) {
    return (gpio_get_level(RELAY_GPIO_PIN) == RELAY_ON_LEVEL);
}