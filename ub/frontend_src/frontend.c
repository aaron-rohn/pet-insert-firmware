#include <xparameters.h>
#include <xintc.h>
#include <fsl.h>

#include "custom_timer.h"
#include "custom_command.h"
#include "custom_iic.h"

// Checks the value of the carry bit and puts it in result
#define fsl_isinvalid(result) asm volatile ("addic\t%0,r0,0"  : "=d" (result))

#define DAC_ADDR 			0x4C
#define DAC_WRITE_UPDATE	0x30
#define DAC_RST	 			0x70
#define ADC0_ADDR 			0x48
#define ADC1_ADDR			0x49
#define THRESH_DEFAULT 		0x6B7 // 50mV
#define BIAS_DEFAULT 		0x000

#define FIFO0 	((volatile uint32_t*)(XPAR_AXI_FIFO_MM_S_0_BASEADDR))
#define GPIO0	((volatile uint32_t*)(XPAR_AXI_GPIO_0_BASEADDR))
#define GPIO1 	((volatile uint32_t*)(XPAR_AXI_GPIO_0_BASEADDR + 0x8))
#define FSL_INTR (XPAR_MICROBLAZE_0_AXI_INTC_SYSTEM_RXD_INTERRUPT_INTR)

XIntc intr_inst;

volatile uint8_t timer_timeout = 0, fsl_got_data = 0;
volatile uint32_t fsl_no_data = 0, cmd_buf = 0;
uint8_t iic_return = 0;

void fsl_handler(void *data)
{
    getfslx(cmd_buf, 0, FSL_NONBLOCKING);
    fsl_isinvalid(fsl_no_data);
    fsl_got_data = !fsl_no_data;
}

void timer_handler(void *data)
{
	*TIMER_TCSR = TIMER_TCSR_DEFAULT | TIMER_TCSR_INT;
	timer_timeout = 1;
}

void intc_initialize()
{
    XIntc_Initialize(&intr_inst, XPAR_MICROBLAZE_0_AXI_INTC_DEVICE_ID);

    XIntc_Connect(&intr_inst, FSL_INTR, (XInterruptHandler) fsl_handler, NULL);
    XIntc_Connect(&intr_inst, XPAR_INTC_0_TMRCTR_0_VEC_ID, (XInterruptHandler) timer_handler, NULL);

    XIntc_Start(&intr_inst, XIN_REAL_MODE);

    XIntc_Enable(&intr_inst, FSL_INTR);
    XIntc_Enable(&intr_inst, XPAR_INTC_0_TMRCTR_0_VEC_ID);

    // Enable exception controller
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XIntc_InterruptHandler, &intr_inst);
    Xil_ExceptionEnable();

    return;
}

int main()
{
    intc_initialize();

    // Soft reset the DAC
    uint8_t iic_write_buf[3] = {DAC_RST, 0, 0};
    iic_return = iic_write(DAC_ADDR, 3, iic_write_buf);

    for (uint8_t i = 0; i < 8 && iic_return == IIC_SUCCESS; i++)
    {
    	// Set default values for all DAC channels

    	uint16_t dac_val = (i < 4) ? THRESH_DEFAULT : BIAS_DEFAULT;

    	iic_write_buf[0] = DAC_WRITE_UPDATE | i;
    	iic_write_buf[1] = (dac_val >> 4);
    	iic_write_buf[2] = (dac_val << 4) & 0xFF;

    	iic_return = iic_write(DAC_ADDR, 3, iic_write_buf);
    }

    while (1)
    {
        if (fsl_got_data)
        {
            fsl_got_data = 0;
			uint8_t d = CMD_COMMAND(cmd_buf);
			uint32_t cmd_response = CMD_EMPTY | ((*GPIO1 & 0xF) << 24) | (d << 20);

			if (d == DAC_WRITE)
			{
				uint8_t  dac_cmd = CMD_DAC_COMMAND(cmd_buf);
				uint8_t  dac_chn = CMD_DAC_CHANNEL(cmd_buf);
				uint16_t dac_val = CMD_DAC_VAL(cmd_buf);
				cmd_response |= ((dac_cmd << 16) | (dac_chn << 12));

				// Update command and DAC value
				iic_write_buf[0] = (dac_cmd << 4) | dac_chn;
				iic_write_buf[1] = (dac_val >> 8) & 0xFF;
				iic_write_buf[2] = (dac_val >> 0) & 0xFF;
				dac_val = 0;

				// Send the update command to the DAC channel
				iic_return = iic_write(DAC_ADDR, 3, iic_write_buf);

				if (iic_return == IIC_SUCCESS)
				{
					// Read command for the channel just updated
					iic_write_buf[0] = (0x10 | dac_chn);
                    iic_write_buf[1] = 0;

					// Send the read command and read back the DAC register
					iic_return = iic_read(DAC_ADDR, 1, iic_write_buf, 2, iic_write_buf);
					dac_val = (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
				}

				cmd_response |= (iic_return ?: dac_val);
			}
			else if (d == ADC_READ)
			{
				uint8_t sys_channel = CMD_ADC_CHANNEL(cmd_buf);
				uint8_t adc_chn  = sys_channel < 4 ? sys_channel : sys_channel - 4;
				uint8_t adc_addr = sys_channel < 4 ? ADC0_ADDR   : ADC1_ADDR;
				uint16_t adc_val = 0;

				// Initiate a conversion
				iic_write_buf[0] = ADC_CONFIG_REG;
				iic_write_buf[1] = ADC_CONFIG_H | (adc_chn << 4);
				iic_write_buf[2] = ADC_CONFIG_L;

				iic_return = iic_write(adc_addr, 3, iic_write_buf);

				// Wait until conversion finishes
				iic_write_buf[0] = 0;
				iic_write_buf[1] = 0;

				while (iic_return == IIC_SUCCESS && (iic_write_buf[0] & ADC_CONFIG_OS) == 0)
				{
					iic_return = iic_read(adc_addr, 0, NULL, 2, iic_write_buf);
				}

				if (iic_return == IIC_SUCCESS)
				{
					// Read back conversion value
					iic_write_buf[0] = ADC_CONVERSION_REG;
                    iic_write_buf[1] = 0;
					iic_return = iic_read(adc_addr, 1, iic_write_buf, 2, iic_write_buf);
				}

				adc_val = iic_return ?: (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
				cmd_response |= (sys_channel << 16) | adc_val;
			}
            else if (d == MODULE_ID)
            {
                // No additional data necessary
            }

            putfslx(cmd_response, 0, FSL_DEFAULT);
		}
    }

    return 0;
}
