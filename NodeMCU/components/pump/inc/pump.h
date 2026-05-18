#ifndef PUMP_H
#define PUMP_H
#include "relay.h"
#include <stdbool.h>

void pump_init(void);
void pump_start(void);
void pump_stop(void); 

/**
 * @brief Read pump status to send to broker
 * @return true if pumping, else false
 */
bool pump_status(void);

#endif