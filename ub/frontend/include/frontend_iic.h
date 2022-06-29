#ifndef _FRONTEND_IIC_H_
#define _FRONTEND_IIC_H_

#include "types.h"
#include "iic.h"
#include <fsl.h>

#define ADC0_ADDR 			0x48
#define ADC1_ADDR			0x49
#define DAC_ADDR            0x4C
//#define DAC_WRITE_UPDATE	0x30
//#define DAC_RST	 			0x70
#define DAC_WRITE_UPDATE	0x3
#define DAC_RST	 			0x7

#define IIC_SUCCESS     0x0
#define IIC_ERR_TXERR   0x1
#define IIC_ERR_RXERR   0x2

#define IIC_BUF_SET(buf, b0, b1, b2) ({\
        buf[0] = b0;\
        buf[1] = b1;\
        buf[2] = b2; })

#define QUEUE_SIZE_MAX 32UL
extern volatile unsigned long queue_size;
extern uint32_t queue[];

#define QUEUE_NEMPTY() ({ queue_size > 0; })

#define QUEUE_PUT(val) ({ \
        microblaze_disable_interrupts(); \
        queue[queue_size] = (val); \
        queue_size++; \
        microblaze_enable_interrupts(); \
})

#define QUEUE_POP() ({ \
        uint32_t cmd = 0; \
        microblaze_disable_interrupts(); \
        queue_size--; \
        cmd = queue[queue_size]; \
        microblaze_enable_interrupts(); \
        cmd; \
})

/*
uint8_t iic_write(uint8_t, uint8_t, uint8_t*);
uint8_t iic_read(uint8_t, uint8_t, uint8_t*, uint8_t, uint8_t*);
uint32_t read_adc_temp(uint8_t);
void dac_write(uint32_t);
uint32_t dac_read(uint8_t);
*/

void frontend_iic_handler() __attribute__((fast_interrupt));

#endif
