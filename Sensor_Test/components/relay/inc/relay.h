#ifndef RELAY_H
#define RELAY_H

#include "driver/gpio.h"
#define RELAY_GPIO_PIN 18
#define RELAY_ON_LEVEL 1
#define RELAY_OFF_LEVEL 0

void relay_init(void);
void relay_on(void);
void relay_off(void);
void relay_toggle(void);

bool relay_status(void);
#endif