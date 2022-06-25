#ifndef _FRONTEND_GPIO_H_
#define _FRONTEND_GPIO_H_

#include "xparameters.h"
#include "types.h"

#define GPIO_SET(base, value, mask, offset) ({ \
        uint32_t scratch = *base; \
        scratch &= ~(mask << offset); \
        scratch |= (value << offset); \
        *base = scratch; })

#define GPIO0 ((volatile uint32_t*)(XPAR_AXI_GPIO_0_BASEADDR + 0x0))
#define GPIO1 ((volatile uint32_t*)(XPAR_AXI_GPIO_0_BASEADDR + 0x8))
#define GPIO2 ((volatile uint32_t*)(XPAR_AXI_GPIO_1_BASEADDR + 0x0))
#define GPIO3 ((volatile uint32_t*)(XPAR_AXI_GPIO_1_BASEADDR + 0x8))

#endif
