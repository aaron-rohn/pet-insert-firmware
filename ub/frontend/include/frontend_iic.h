#ifndef _FRONTEND_IIC_H_
#define _FRONTEND_IIC_H_

#include "types.h"
#include "iic.h"
#include "command.h"
#include <fsl.h>

#define ADC0_ADDR 			0x48
#define ADC1_ADDR			0x49
#define DAC_ADDR            0x4C
#define DAC_WRITE_UPDATE	0x3
#define DAC_RST	 			0x7
#define ADC_NCH             8

// 50mv, 35C
#define THRESH_DEFAULT      0x6B7
#define TEMP_THRESH_DEFAULT 0x3DC

void queue_put(uint32_t);
uint32_t queue_pop();

extern volatile uint32_t temp_values[];
extern volatile uint16_t temp_thresh;
extern volatile uint8_t module_id;

void frontend_iic_handler() __attribute__((fast_interrupt));

#endif
