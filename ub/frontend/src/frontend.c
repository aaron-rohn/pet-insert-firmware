#include <fsl.h>
#include "intc.h"
#include "command.h"
#include "frontend_gpio.h"
#include "frontend_iic.h"

volatile uint8_t module_id;

int main()
{
    module_id = *GPIO0 & 0xF;
    microblaze_enable_interrupts();
    INTC_REGISTER(frontend_iic_handler, 0);
    INTC_ENABLE(0x1);

    uint32_t cmd = 0;
    cmd = CMD_DAC_BUILD(DAC_RST, 0, 0);
    cmd = CMD_BUILD(module_id, DAC_WRITE, cmd);
    queue_put(cmd);

    for (uint8_t i = 0; i < 4; i++)
    {
        cmd = CMD_DAC_BUILD(DAC_WRITE_UPDATE, i, THRESH_DEFAULT);
        cmd = CMD_BUILD(module_id, DAC_WRITE, cmd);
        queue_put(cmd);
    }

    IIC_INIT(IIC_ISR_DEFAULT);

    while (1)
    {
        // read and handle commands from backend

        uint32_t fsl_no_data = 1, cmd = 0;
        getfslx(cmd, 0, FSL_NONBLOCKING);
        fsl_isinvalid(fsl_no_data);

        if (!fsl_no_data)
        {
            enum cmd_t c = CMD_COMMAND(cmd);
            uint32_t value = 0;
            uint8_t channel = 0;
            uint8_t divisor = 0;

            switch(c)
            {
                case MODULE_ID:
                    // no additional data needed in payload
                    break;

                case DAC_WRITE:
                    queue_put(cmd);
                    value = CMD_DAC_VAL(cmd);
                    break;

                case DAC_READ:
                    queue_put(cmd);
                    // return value is provided by ISR
                    continue;

                case ADC_READ:
                    value = temp_values[CMD_ADC_CHANNEL(cmd)];
                    break;

                case PERIOD_READ:
                    divisor = cmd & 0xFF;
                    value = *GPIO3;
                    value >>= divisor;
                    break;

                case SGL_RATE_READ:
                    divisor = cmd & 0xFF;
                    channel = (cmd >> 8) & 0x3;
                    GPIO_SET(GPIO1, channel, 0x3, 0);
                    value = *GPIO2;
                    value >>= divisor;
                    break;

                case GPIO_FRONTEND:
                    if (GPIO_RW(cmd))
                    {
                        GPIO_SET(GPIO1,
                                 GPIO_VALUE(cmd),
                                 GPIO_MASK(cmd),
                                 GPIO_OFF(cmd));
                    }

                    value = *GPIO1;
                    value = (value >> GPIO_OFF(cmd)) & GPIO_MASK(cmd);
                    break;

                case UPDATE_REG:
                    value = temp_thresh;
                    temp_thresh = cmd & 0xFFFF;
                    break;

                default:
                    break;
            }

            value = CMD_BUILD(module_id, c, value);
            putfslx(value, 0, FSL_DEFAULT);
        }
    }

    return 0;
}
