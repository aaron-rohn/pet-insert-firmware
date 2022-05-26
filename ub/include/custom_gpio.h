#ifndef CUSTOM_GPIO_H
#define CUSTOM_GPIO_H

#include "custom_command.h"

uint32_t handle_gpio(uint32_t);
uint32_t handle_counter(uint32_t);

#define MODULE_CLR_PWR(num) ({      \
    uint32_t value = GPIO_RD_O();   \
    value &= ~(0x1 << (num+4));     \
    GPIO_WR_O(value); })

#define MODULE_PWR_IS_SET(num) ((GPIO_RD_O() >> (num + 4)) & 0x1)

#endif
