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
    SPI_INIT();

	while(1)
	{
        uint32_t cmd = 0;
        if (SPI_RX_VALID())
        {
            cmd = SPI_READ();
        }

        if (IS_CMD(cmd))
        {
            // Ensure that the workstation is not reading a stale value
            SPI_WRITE(0);

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

                default:
                    // forward the command to the indicated module
                    value = CMD_MODULE_LOWER(cmd);
                    putdfslx(cmd, value, FSL_DEFAULT);
                    cmd = value;
                    break;
            }

            // return an immediate response to the workstation
            SPI_WRITE(cmd);
        }

        // read FSL from frontend and write to SPI
        for (uint32_t i = 0; i < XPAR_MICROBLAZE_0_FSL_LINKS; i++)
        {
            uint32_t value = 0, invalid = 1;
            getdfslx(value, i, FSL_NONBLOCKING);
            fsl_isinvalid(invalid);

            if (!invalid)
            {
                // forward frontend response to workstation
                SPI_WRITE(value);
            }
        }
	}

	return 0;
}
