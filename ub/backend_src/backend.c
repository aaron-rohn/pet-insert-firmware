#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_iic.h"
#include "custom_spi.h"
#include "custom_gpio.h"

uint32_t handle_current(uint32_t cmd)
{
    uint32_t value = 0;
    value = CMD_MODULE_LOWER(cmd);
    value = ADC_CH_MAP(value);
    value = backend_current_read(value);
    CMD_SET_PAYLOAD(cmd, value);
    return cmd;
}

int main()
{
    GPIO_SET_FPGA_LED();

    SPI_RST();
    SPI_INIT();

	while(1)
	{
        uint32_t cmd = 0;
        if (SPI_RX_VALID())
        {
            cmd = SPI_READ();
        }

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
                    cmd = handle_current(cmd);
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
                // forward frontend response to workstation
                SPI_WRITE(value);
            }
        }
	}

	return 0;
}
