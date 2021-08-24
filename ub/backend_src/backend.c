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

        // generate command response
        if (cmd_valid)
		{
            cmd_t c = CMD_COMMAND(cmd);

            switch (c) {
                case RST: // only rst board responds
                case NOP: // no-op, just checking if alive
                    SPI_WRITE(cmd);
                    break;

                case GPIO:
                    // read up to 8 bits from the gpio inputs
                    value = (GPIO_RD_I() >> GPIO_OFF(cmd)) & GPIO_MASK(cmd);
                    CMD_SET_PAYLOAD(cmd, value);
                    SPI_WRITE(cmd);
                    break;

                case SET_POWER:
                    if (PWR_UPDATE(cmd))
                    {
                        // turn on/off power to the specified modules
                        value = GPIO_RD_O() & ~(0xF << 4);
                        value |= (PWR_MASK(cmd) << 4);
                        GPIO_WR_O(value);
                    }
                    // read and return power status
                    value = (GPIO_RD_O() >> 4) & 0xF;
                    CMD_SET_PAYLOAD(cmd, value);
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
                    break;
            }
		}
	}
	return 0;
}
