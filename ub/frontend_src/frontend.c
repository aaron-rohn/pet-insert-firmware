#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_iic.h"

#define DAC_ADDR 			0x4C
#define DAC_WRITE_UPDATE	0x30
#define DAC_RST	 			0x70
#define ADC0_ADDR 			0x48
#define ADC1_ADDR			0x49
#define THRESH_DEFAULT 		0x6B7 // 50mV
#define BIAS_DEFAULT 		0x000 // 0.0V
#define GPIO1()	            Xil_In32(XPAR_AXI_GPIO_0_BASEADDR)

int main()
{
    uint32_t fsl_no_data = 0, cmd_buf = 0;
    uint8_t iic_return = 0;

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
        fsl_no_data = 1;
        getfslx(cmd_buf, 0, FSL_NONBLOCKING);
        fsl_isinvalid(fsl_no_data);

        if (!fsl_no_data)
        {
            cmd_t c = CMD_COMMAND(cmd_buf);
            uint8_t module_id = GPIO1() & 0xF;
            uint8_t cmd_or_addr = 0;
            uint8_t channel = 0;
            uint32_t value = 0;

            switch(c)
            {
                case DAC_WRITE:
                    cmd_or_addr = CMD_DAC_COMMAND(cmd_buf);
                    channel     = CMD_DAC_CHANNEL(cmd_buf);
                    value       = CMD_DAC_VAL(cmd_buf);

                    // Update command and DAC value
                    iic_write_buf[0] = (cmd_or_addr << 4) | channel;
                    iic_write_buf[1] = (value >> 8) & 0xFF;
                    iic_write_buf[2] = (value >> 0) & 0xFF;
                    value = 0;

                    // Send the update command to the DAC channel
                    iic_return = iic_write(DAC_ADDR, 3, iic_write_buf);

                    if (iic_return == IIC_SUCCESS)
                    {
                        // Read command for the channel just updated
                        iic_write_buf[0] = 0x10 | channel;
                        iic_write_buf[1] = 0;

                        // Send the read command and read back the DAC register
                        iic_return = iic_read(DAC_ADDR, 1, iic_write_buf, 2, iic_write_buf);
                        value = (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
                    }
                    break;

                case ADC_READ:
                    // system channel, 0-7
                    channel = CMD_ADC_CHANNEL(cmd_buf);
                    // ADC0 -> channels 0-3, ADC1 -> channels 4-7
                    cmd_or_addr = channel < 4 ? ADC0_ADDR : ADC1_ADDR;
                    // map system channel to ADC0/1 channel
                    channel %= 4;

                    // Initiate a conversion
                    iic_write_buf[0] = ADC_CONFIG_REG;
                    iic_write_buf[1] = ADC_CONFIG_H | (channel << 4);
                    iic_write_buf[2] = ADC_CONFIG_L;

                    iic_return = iic_write(cmd_or_addr, 3, iic_write_buf);

                    // Wait until conversion finishes
                    iic_write_buf[0] = 0;
                    iic_write_buf[1] = 0;

                    while (iic_return == IIC_SUCCESS && (iic_write_buf[0] & ADC_CONFIG_OS) == 0)
                    {
                        iic_return = iic_read(cmd_or_addr, 0, NULL, 2, iic_write_buf);
                    }

                    if (iic_return == IIC_SUCCESS)
                    {
                        // Read back conversion value
                        iic_write_buf[0] = ADC_CONVERSION_REG;
                        iic_write_buf[1] = 0;
                        iic_return = iic_read(cmd_or_addr, 1, iic_write_buf, 2, iic_write_buf);
                    }

                    value = (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
                    break;

                case MODULE_ID:
                    // no additional data needed in payload
                default:
                    break;
            }

            value = iic_return ?: value;
			value = CMD_BUILD(module_id, c, value);
            putfslx(value, 0, FSL_DEFAULT);
		}
    }

    return 0;
}
