#ifndef _FRONTEND_IIC_H_
#define _FRONTEND_IIC_H_

#include "types.h"
#include "iic.h"

#define ADC0_ADDR 			0x48
#define ADC1_ADDR			0x49
#define DAC_ADDR            0x4C
#define DAC_WRITE_UPDATE	0x30
#define DAC_RST	 			0x70

#define IIC_SUCCESS     0x0
#define IIC_ERR_TXERR   0x1
#define IIC_ERR_RXERR   0x2

#define IIC_BUF_SET(buf, b0, b1, b2) ({\
        buf[0] = b0;\
        buf[1] = b1;\
        buf[2] = b2; })

uint8_t iic_write(uint8_t, uint8_t, uint8_t*);
uint8_t iic_read(uint8_t, uint8_t, uint8_t*, uint8_t, uint8_t*);

uint32_t read_adc_temp(uint8_t);
void dac_write(uint32_t);
uint32_t dac_read(uint8_t);

void frontend_iic_handler() __attribute__((fast_interrupt));

#endif
