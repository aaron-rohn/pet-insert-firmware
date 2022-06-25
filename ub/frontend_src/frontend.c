#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "custom_gpio.h"
#include "custom_command.h"
#include "custom_iic.h"

#define DAC_ADDR 			0x4C
#define DAC_WRITE_UPDATE	0x30
#define DAC_RST	 			0x70
#define ADC0_ADDR 			0x48
#define ADC1_ADDR			0x49
#define THRESH_DEFAULT 		0x6B7 // 50mV

uint8_t iic_write_buf[3] = {0};
#define IIC_BUF_SET(b0,b1,b2) ({\
        iic_write_buf[0] = b0; \
        iic_write_buf[1] = b1; \
        iic_write_buf[2] = b2; })

uint32_t read_adc_temp(uint8_t channel)
{
    // ADC0 -> channels 0-3, ADC1 -> channels 4-7
    uint8_t adc_addr = channel < 4 ? ADC0_ADDR : ADC1_ADDR;
    // map system channel to ADC0/1 channel
    channel %= 4;

    // Initiate a conversion
    IIC_BUF_SET(ADC_CONFIG_REG, ADC_CONFIG_H | (channel << 4), ADC_CONFIG_L);
    uint8_t iic_return = iic_write(adc_addr, 3, iic_write_buf);

    // Wait until conversion finishes
    IIC_BUF_SET(0xFF,0,0);
    while (iic_return == IIC_SUCCESS && (iic_write_buf[0] & ADC_CONFIG_OS) == 0)
    {
        iic_return = iic_read(adc_addr, 0, NULL, 2, iic_write_buf);
    }

    // Read back conversion value
    IIC_BUF_SET(ADC_CONVERSION_REG, 0, 0);
    iic_read(adc_addr, 1, iic_write_buf, 2, iic_write_buf);
    return (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
}

void dac_write(uint32_t cmd_buf)
{
    uint8_t dac_cmd = CMD_DAC_COMMAND(cmd_buf);
    uint8_t channel = CMD_DAC_CHANNEL(cmd_buf);
    uint32_t value  = CMD_DAC_VAL(cmd_buf);
    IIC_BUF_SET((dac_cmd << 4) | channel, (value >> 8) & 0xFF, value & 0xFF);
    iic_write(DAC_ADDR, 3, iic_write_buf);
}

uint32_t dac_read(uint8_t channel)
{
    IIC_BUF_SET(0x10 | channel, 0, 0);
    iic_read(DAC_ADDR, 1, iic_write_buf, 2, iic_write_buf);
    return (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
}

int main()
{
    // Soft reset the DAC
    IIC_BUF_SET(DAC_RST, 0, 0);
    iic_write(DAC_ADDR, 3, iic_write_buf);

    for (uint8_t i = 0; i < 4; i++)
    {
    	// Set default threshold values for DAC channels 0-3
        // Bias defaults to 0 at power on/reset
        IIC_BUF_SET(DAC_WRITE_UPDATE | i, THRESH_DEFAULT >> 4, (THRESH_DEFAULT << 4) & 0xFF);
    	iic_write(DAC_ADDR, 3, iic_write_buf);
    }

    uint8_t module_id = *GPIO0 & 0xF;
    uint8_t curr_chan = 0;
    uint32_t temp_values[8] = {0};

    // default temperature threshold is ~35C
    uint16_t temp_adc_thresh = 0x3DC;

    while (1)
    {
        // read a temperature value on each loop
        temp_values[curr_chan] = read_adc_temp(curr_chan);

        // detect over temperature condition
        if (temp_values[curr_chan] > temp_adc_thresh)
        {
            // send a power-off request to the backend
            uint32_t value = CMD_BUILD(module_id, CMD_RESPONSE, 0);
            putfslx(value, 0, FSL_DEFAULT);
        }
        curr_chan = (curr_chan + 1) % 8;

        // read and handle commands from backend

        uint32_t fsl_no_data = 1, cmd_buf = 0;
        getfslx(cmd_buf, 0, FSL_NONBLOCKING);
        fsl_isinvalid(fsl_no_data);

        if (!fsl_no_data)
        {
            cmd_t c = CMD_COMMAND(cmd_buf);
            uint32_t value = 0;
            uint8_t channel = 0;
            uint8_t divisor = 0;

            switch(c)
            {
                case MODULE_ID:
                    // no additional data needed in payload
                    break;

                case DAC_WRITE:
                    dac_write(cmd_buf);
                case DAC_READ:
                    value = dac_read(CMD_DAC_CHANNEL(cmd_buf));
                    break;

                case ADC_READ:
                    value = temp_values[CMD_ADC_CHANNEL(cmd_buf)];
                    break;

                case PERIOD_READ:
                    divisor = cmd_buf & 0xFF;
                    value = *GPIO3;
                    value >>= divisor;
                    break;

                case SGL_RATE_READ:
                    divisor = cmd_buf & 0xFF;
                    channel = (cmd_buf >> 8) & 0x3;
                    GPIO_SET(GPIO1, channel, 0x3, 0);
                    value = *GPIO2;
                    value >>= divisor;
                    break;

                case GPIO_FRONTEND:
                    if (GPIO_RW(cmd_buf))
                    {
                        GPIO_SET(GPIO1,
                                 GPIO_VALUE(cmd_buf),
                                 GPIO_MASK(cmd_buf),
                                 GPIO_OFF(cmd_buf));
                    }

                    value = *GPIO1;
                    value = (value >> GPIO_OFF(cmd_buf)) & GPIO_MASK(cmd_buf);
                    break;

                case UPDATE_REG:
                    value = temp_adc_thresh;
                    temp_adc_thresh = cmd_buf & 0xFFFF;
                    break;

                default: break;
            }

            value = CMD_BUILD(module_id, c, value);
            putfslx(value, 0, FSL_DEFAULT);
        }
    }

    return 0;
}
