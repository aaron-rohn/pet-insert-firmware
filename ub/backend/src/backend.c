#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "intc.h"
#include "command.h"
#include "backend_iic.h"
#include "backend_spi.h"
#include "backend_gpio.h"
#include "backend_timer.h"

int main()
{
    // Begin initialization

    *GPIO0 &= ~GPIO_SOFT_RST;
    *GPIO0 |= (GPIO_STATUS_NET | GPIO_STATUS_FPGA);
    TIMER_INT_CLEAR();
    SPI_RST();

    microblaze_enable_interrupts();
    INTC_REGISTER(timer_handler, 0);
    INTC_REGISTER(backend_iic_handler, 1);
    INTC_ENABLE(0x3);

    TIMER_INIT(TIME_60S);
    IIC_INIT(IIC_ISR_DEFAULT);
    SPI_INIT();

    // End initialization

	while(1)
	{
        // check for command from workstation
        uint32_t cmd = 0;
        if (SPI_RX_VALID())
        {
            cmd = SPI_READ();
            TIMER_INIT(TIME_60S);
        }

        // handle commands

        if (cmd == 1)
        {
            SPI_RST();
            SPI_INIT();
        }
        else if (IS_CMD(cmd))
        {
            cmd_t c = CMD_COMMAND(cmd);
            uint32_t value = 0;

            switch (c)
            {
                case NOP:
                    break;

                case GPIO:
                    cmd = handle_gpio(cmd);
                    break;

                case GET_CURRENT:
                    value = CMD_MODULE_LOWER(cmd);
                    CMD_SET_PAYLOAD(cmd, current_values[value]);
                    break;

                case COUNTER_READ:
                    cmd = handle_counter(cmd);
                    break;

                case UPDATE_REG:
                    if (UPDATE_REG_BACKEND(cmd)) {
                        value = current_thresh;
                        current_thresh = cmd & 0xFFFF;
                        CMD_SET_PAYLOAD(cmd, value);
                        break;
                    };
                    // else fall through

                default:
                    // forward the command to the indicated module
                    value = CMD_MODULE_LOWER(cmd);
                    putdfslx(cmd, value, FSL_DEFAULT);
                    cmd = CMD_BUILD(
                            value,
                            CMD_RESPONSE,
                            MODULE_PWR_IS_SET(value));
            }

            SPI_WRITE(cmd);
        }

        // read FSL from frontend and write to SPI
        for (uint32_t i = 0; i < XPAR_MICROBLAZE_0_FSL_LINKS; i++)
        {
            uint32_t value = 0, invalid = 1;
            getdfslx(value, i, FSL_NONBLOCKING);
            fsl_isinvalid(invalid);

            // Only send responses to the workstation if the
            // power should be on. Sometimes some invalid data
            // is generated when powering off the module
            if (!invalid && MODULE_PWR_IS_SET(i))
            {
                // frontend module indicates over-temperature
                if (CMD_COMMAND(value) == CMD_RESPONSE)
                {
                    // power off the specified module
                    MODULE_CLR_PWR(i);
                }
                else
                {
                    // forward frontend response to workstation
                    SPI_WRITE(value);
                }
            }
        }
	}

	return 0;
}
