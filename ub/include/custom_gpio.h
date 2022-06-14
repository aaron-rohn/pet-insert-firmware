#ifndef CUSTOM_GPIO_H
#define CUSTOM_GPIO_H

#include "custom_command.h"

uint32_t handle_gpio(uint32_t);
uint32_t handle_counter(uint32_t);

#define GPIO_BASE XPAR_GPIO_0_BASEADDR
#define GPIO0 ((volatile uint32_t*)(GPIO_BASE + 0x00))
#define GPIO_SOFT_RST    (1 << 0)
#define GPIO_STATUS_FPGA (1 << 1)
#define GPIO_STATUS_NET  (1 << 2)

#define GPIO_SET(base, value, mask, offset) do { \
        uint32_t scratch = Xil_In32(base); \
        scratch &= ~(mask << offset); \
        scratch |= (value << offset); \
        Xil_Out32(base, scratch); } while (0)

#define MODULE_CLR_PWR(num) ({      \
    uint32_t value = GPIO_RD_O();   \
    value &= ~(0x1 << (num+4));     \
    GPIO_WR_O(value); })

#define MODULE_PWR_IS_SET(num) ((GPIO_RD_O() >> (num + 4)) & 0x1)

#endif
