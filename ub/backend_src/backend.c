#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_iic.h"
#include "custom_spi.h"

int main()
{
    GPIO_SET_FPGA_LED();
    SPI_INIT();

    uint32_t cmd, cmd_valid, value;
    uint32_t frontend_value, frontend_invalid;

	while(1)
	{
        // read FSL from frontend and write to SPI
        for (uint32_t i = 0; i < XPAR_MICROBLAZE_0_FSL_LINKS; i++)
        {
            frontend_invalid = 1;
            getdfslx(frontend_value, i, FSL_NONBLOCKING);
            fsl_isinvalid(frontend_invalid);
            if (!frontend_invalid)
            {
                // forward frontend response to workstation
                SPI_WRITE(frontend_value);
            }
        }

        // read from SPI and respond to commands
        cmd_valid = 0;
        if (SPI_RX_VALID())
        {
            cmd = SPI_READ();
            cmd_valid = IS_CMD(cmd);
            SPI_TX_RST();
        }

        // no command received -- do not generate a response
        if (!cmd_valid) continue;

        // generate command response
        cmd_t c = CMD_COMMAND(cmd);

        switch (c)
        {
            case GPIO:
                // read or write the two GPIO banks
                // Handles reset, power, LED, and status reading

                if (GPIO_RW(cmd))
                {
                    // write to bank 0
                    value = GPIO_RD_O();
                    value &= ~(GPIO_MASK(cmd) << GPIO_OFF(cmd));
                    value |= (GPIO_MASK(cmd) & GPIO_VALUE(cmd)) << GPIO_OFF(cmd);
                    GPIO_WR_O(value);
                }

                // read back from the specified bank
                value = GPIO_RD(GPIO_BANK(cmd));
                value = (value >> GPIO_OFF(cmd)) & GPIO_MASK(cmd);

                CMD_SET_PAYLOAD(cmd, value);
                SPI_WRITE(cmd);
                break;

            case NOP:
                // no-op, just checking if alive
                SPI_WRITE(cmd);
                break;

            case GET_CURRENT:
                value = ADC_CH_MAP(CMD_MODULE_LOWER(cmd));
                value = backend_current_read(value);
                CMD_SET_PAYLOAD(cmd, value);
                SPI_WRITE(cmd);
                break;

            default:
                // forward the command to the indicated module
                // no response to workstation yet - wait for frontend resp
                value = CMD_MODULE_LOWER(cmd);
                putdfslx(cmd, value, FSL_DEFAULT);
		}
	}

	return 0;
}
