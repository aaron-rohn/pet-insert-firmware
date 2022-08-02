#ifndef _BACKEND_GPIO_H_
#define _BACKEND_GPIO_H_

#include "xparameters.h"
#include "types.h"

uint32_t handle_gpio(uint32_t);
uint32_t handle_counter(uint32_t);

#define GPIO0 ((volatile uint32_t*)(XPAR_AXI_GPIO_0_BASEADDR + 0x0))
#define GPIO1 ((volatile uint32_t*)(XPAR_AXI_GPIO_0_BASEADDR + 0x8))

#define GPIO_SOFT_RST    (1 << 0)
#define GPIO_STATUS_FPGA (1 << 1)
#define GPIO_STATUS_NET  (1 << 2)

#define MODULE_CLR_PWR(num) ({ *GPIO0 &= ~(0x1 << (num+4)); })
#define MODULE_PWR_IS_SET(num) (((*GPIO0) >> (num + 4)) & 0x1)

#endif
