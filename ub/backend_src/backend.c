#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_iic.h"
#include "custom_spi.h"
#include "custom_gpio.h"

#define CURRENT_THRESHOLD 1500

int main()
{
    GPIO_SET_FPGA_LED();

    SPI_RST();
    SPI_INIT();

    uint8_t ch = 0;
    uint32_t vals[4] = {0};

	while(1)
	{
        // measure current on each loop

        vals[ch] = backend_current_read(ch);
        if (vals[ch] > CURRENT_THRESHOLD)
        {
            // power off module in case of over-current
            MODULE_CLR_PWR(ch);
        }
        ch = (ch + 1) % 4;

        // check for command from workstation

        uint32_t cmd = 0;
        if (SPI_RX_VALID())
        {
            cmd = SPI_READ();
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
                    CMD_SET_PAYLOAD(cmd, vals[value]);
                    break;

                case COUNTER_READ:
                    cmd = handle_counter(cmd);
                    break;

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

            /*
             * Only send responses to the workstation if the
             * power should be on. Sometimes some invalid data
             * is generated when powering off the module
             */
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
