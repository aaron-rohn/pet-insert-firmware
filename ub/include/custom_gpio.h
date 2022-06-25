#ifndef CUSTOM_GPIO_H
#define CUSTOM_GPIO_H

#include "custom_command.h"

uint32_t handle_gpio(uint32_t);
uint32_t handle_counter(uint32_t);

#define GPIO_SET(base, value, mask, offset) ({ \
        uint32_t scratch = *base; \
        scratch &= ~(mask << offset); \
        scratch |= (value << offset); \
        *base = scratch; })

#define GPIO0 ((volatile uint32_t*)(XPAR_AXI_GPIO_0_BASEADDR + 0x0))
#define GPIO1 ((volatile uint32_t*)(XPAR_AXI_GPIO_0_BASEADDR + 0x8))

#if XPAR_XGPIO_NUM_INSTANCES==2
// frontend

#define GPIO2 ((volatile uint32_t*)(XPAR_AXI_GPIO_1_BASEADDR + 0x0))
#define GPIO3 ((volatile uint32_t*)(XPAR_AXI_GPIO_1_BASEADDR + 0x8))

#else
// backend

#define GPIO_SOFT_RST    (1 << 0)
#define GPIO_STATUS_FPGA (1 << 1)
#define GPIO_STATUS_NET  (1 << 2)

#define MODULE_CLR_PWR(num) ({ *GPIO0 &= ~(0x1 << (num+4)); })
#define MODULE_PWR_IS_SET(num) (((*GPIO0) >> (num + 4)) & 0x1)

#endif

#endif
