#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "intc.h"
#include "command.h"
#include "frontend_gpio.h"
#include "frontend_iic.h"

#define THRESH_DEFAULT 0x6B7 // 50mV

int main()
{
    microblaze_enable_interrupts();
    INTC_REGISTER(frontend_iic_handler, 0x1);
    INTC_ENABLE(0x1);
    IIC_INIT(IIC_ISR_DEFAULT);

    uint8_t buf[3] = {0};

    // Soft reset the DAC
    IIC_BUF_SET(buf, DAC_RST, 0, 0);
    iic_write(DAC_ADDR, 3, buf);

    for (uint8_t i = 0; i < 4; i++)
    {
    	// Set default threshold values for DAC channels 0-3
        // Bias defaults to 0 at power on/reset
        IIC_BUF_SET(buf, DAC_WRITE_UPDATE | i, THRESH_DEFAULT >> 4, (THRESH_DEFAULT << 4) & 0xFF);
    	iic_write(DAC_ADDR, 3, buf);
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
                    //dac_write(cmd_buf);
                case DAC_READ:
                    //value = dac_read(CMD_DAC_CHANNEL(cmd_buf));
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
