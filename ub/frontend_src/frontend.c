#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_iic.h"

#define GPIO_0 XPAR_AXI_GPIO_0_BASEADDR
#define GPIO_1 (XPAR_AXI_GPIO_0_BASEADDR + 0x8)
#define GPIO_2 XPAR_AXI_GPIO_1_BASEADDR
#define GPIO_3 (XPAR_AXI_GPIO_1_BASEADDR + 0x8)

#define DAC_ADDR 			0x4C
#define DAC_WRITE_UPDATE	0x30
#define DAC_RST	 			0x70
#define ADC0_ADDR 			0x48
#define ADC1_ADDR			0x49
#define THRESH_DEFAULT 		0x6B7 // 50mV
#define GPIO0_IN()	        Xil_In32(GPIO_0)
#define SGL_RATE_GPIO()     Xil_In32(GPIO_2)
#define PERIOD_GPIO()       Xil_In32(GPIO_3)

#define GPIO_SET(base, value, mask, offset) do { \
        uint32_t scratch = Xil_In32(base); \
        scratch &= ~(mask << offset); \
        scratch |= (value << offset); \
        Xil_Out32(base, scratch); } while (0)

#define TT_STALL    2
#define BLK_DISABLE 3
#define SOFT_RST    4

int main()
{
    // Soft reset the DAC
    uint8_t iic_write_buf[3] = {DAC_RST, 0, 0};
    iic_write(DAC_ADDR, 3, iic_write_buf);

    for (uint8_t i = 0; i < 4; i++)
    {
    	// Set default threshold values for DAC channels 0-3
        // Bias defaults to 0 at power on/reset
    	iic_write_buf[0] = DAC_WRITE_UPDATE | i;
    	iic_write_buf[1] = (THRESH_DEFAULT >> 4);
    	iic_write_buf[2] = (THRESH_DEFAULT << 4) & 0xFF;
    	iic_write(DAC_ADDR, 3, iic_write_buf);
    }

    while (1)
    {
        uint32_t fsl_no_data = 1, cmd_buf = 0;
        getfslx(cmd_buf, 0, FSL_NONBLOCKING);
        fsl_isinvalid(fsl_no_data);

        if (fsl_no_data) continue;

        uint8_t iic_return = IIC_SUCCESS;

        cmd_t c = CMD_COMMAND(cmd_buf);
        uint8_t module_id = GPIO0_IN() & 0xF;
        uint32_t value = 0;
        uint8_t channel = 0;

        uint8_t dac_cmd  = 0;
        uint8_t adc_addr = 0;
        uint8_t divisor = 0;

        switch(c)
        {
            case MODULE_ID:
                // no additional data needed in payload
                break;

            case DAC_WRITE:
                dac_cmd = CMD_DAC_COMMAND(cmd_buf);
                channel = CMD_DAC_CHANNEL(cmd_buf);
                value   = CMD_DAC_VAL(cmd_buf);

                // Update command and DAC value
                iic_write_buf[0] = (dac_cmd << 4) | channel;
                iic_write_buf[1] = (value >> 8) & 0xFF;
                iic_write_buf[2] = (value >> 0) & 0xFF;

                // Send the update command to the DAC channel
                iic_write(DAC_ADDR, 3, iic_write_buf);

                // Fall-through

            case DAC_READ:

                channel = CMD_DAC_CHANNEL(cmd_buf);

                iic_write_buf[0] = 0x10 | channel;
                iic_write_buf[1] = 0;

                // Send the read command and read back the DAC register
                iic_read(DAC_ADDR, 1, iic_write_buf, 2, iic_write_buf);
                value = (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
                break;

            case ADC_READ:
                // system channel, 0-7
                channel = CMD_ADC_CHANNEL(cmd_buf);
                // ADC0 -> channels 0-3, ADC1 -> channels 4-7
                adc_addr = channel < 4 ? ADC0_ADDR : ADC1_ADDR;
                // map system channel to ADC0/1 channel
                channel %= 4;

                // Initiate a conversion
                iic_write_buf[0] = ADC_CONFIG_REG;
                iic_write_buf[1] = ADC_CONFIG_H | (channel << 4);
                iic_write_buf[2] = ADC_CONFIG_L;

                iic_return = iic_write(adc_addr, 3, iic_write_buf);

                // Wait until conversion finishes
                iic_write_buf[0] = 0;
                iic_write_buf[1] = 0;

                while (iic_return == IIC_SUCCESS && (iic_write_buf[0] & ADC_CONFIG_OS) == 0)
                {
                    iic_return = iic_read(adc_addr, 0, NULL, 2, iic_write_buf);
                }

                // Read back conversion value
                iic_write_buf[0] = ADC_CONVERSION_REG;
                iic_write_buf[1] = 0;
                iic_read(adc_addr, 1, iic_write_buf, 2, iic_write_buf);
                value = (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
                break;

            case PERIOD_READ:
                divisor = cmd_buf & 0xFF;
                value = PERIOD_GPIO();
                value >>= divisor;
                break;

            case SGL_RATE_READ:
                divisor = cmd_buf & 0xFF;
                channel = (cmd_buf >> 8) & 0x3;
                GPIO_SET(GPIO_1, channel, 0x3, 0);
                value = SGL_RATE_GPIO();
                value >>= divisor;
                break;

            case GPIO_FRONTEND:
                if (GPIO_RW(cmd_buf))
                {
                    GPIO_SET(GPIO_1,
                             GPIO_VALUE(cmd_buf),
                             GPIO_MASK(cmd_buf),
                             GPIO_OFF(cmd_buf));
                }

                value = Xil_In32(GPIO_1);
                value = (value >> GPIO_OFF(cmd_buf)) & GPIO_MASK(cmd_buf);
                break;

            default: break;
        }

        value = CMD_BUILD(module_id, c, value);
        putfslx(value, 0, FSL_DEFAULT);
    }

    return 0;
}
