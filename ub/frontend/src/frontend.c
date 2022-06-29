#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "intc.h"
#include "command.h"
#include "frontend_gpio.h"
#include "frontend_iic.h"

#define THRESH_DEFAULT 0x6B7 // 50mV

extern volatile uint32_t temp_values[];
extern uint16_t temp_adc_thresh;

uint8_t module_id;

int main()
{
    module_id = *GPIO0 & 0xF;

    microblaze_enable_interrupts();
    INTC_REGISTER(frontend_iic_handler, 0x1);
    INTC_ENABLE(0x1);

    QUEUE_PUT(CMD_DAC_BUILD(DAC_RST, 0, 0));
    for (uint8_t i = 0; i < 4; i++)
    {
        QUEUE_PUT(CMD_DAC_BUILD(DAC_WRITE_UPDATE, i, THRESH_DEFAULT));
    }

    IIC_INIT(IIC_ISR_DEFAULT);

    while (1)
    {
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
                case DAC_READ:
                    QUEUE_PUT(cmd_buf);
                    // skip putting a result onto the FSL!
                    // This will be done by the isr when the iic is complete
                    continue;

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
