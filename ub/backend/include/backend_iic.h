#ifndef _BACKEND_IIC_H_
#define _BACKEND_IIC_H_

#include "types.h"
#include "iic.h"

#define ADC_ADDR 0x48

enum iic_state_t {
    WRITE, 
    WAIT_TOP,
    WAIT_BOT,
    RD_TOP, 
    RD_BOT
};

void backend_iic_handler() __attribute__((fast_interrupt));

#endif
