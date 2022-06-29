#ifndef _BACKEND_IIC_H_
#define _BACKEND_IIC_H_

#include "types.h"
#include "iic.h"

#define ADC_ADDR 0x48

void backend_iic_handler() __attribute__((fast_interrupt));

#endif
