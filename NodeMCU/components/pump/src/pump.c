#include "pump.h"


void pump_init() {
    relay_init();
}

void pump_start() {
    relay_on();
}

void pump_stop() {
    relay_off();
}
bool pump_status(void) {
    return relay_status();
}