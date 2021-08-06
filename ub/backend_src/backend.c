#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_iic.h"

// Checks the value of the carry bit and puts it in result
#define fsl_isinvalid(result) asm volatile ("addic\t%0,r0,0"  : "=d" (result))
#define BACKEND_FSL_PORT        0
#define FRONTEND_FSL_PORT       1

int main()
{
    // Turn on the "fpga" LED
    Xil_Out32(XPAR_GPIO_0_BASEADDR, 0x1 << 1);

    uint32_t cmd = 0;
    uint32_t cmd_invalid = 0;

	while(1)
	{
        // check for a command from the ethernet interface
        getfslx(cmd, BACKEND_FSL_PORT, FSL_NONBLOCKING);
        fsl_isinvalid(cmd_invalid);

        if (!cmd_invalid)
		{
            uint32_t value;
            cmd_t    c = CMD_COMMAND(cmd);
            uint32_t m = CMD_MODULE(cmd);
            
            switch (c) {
                case RST: // only rst board responds
                case BACKEND_STATUS: // no-op, just checking if alive
                    break;

                case GPIO_RD_BACKEND:
                    // read up to 8 bits from the gpio
                    value = Xil_In32(XPAR_GPIO_0_BASEADDR + 0x8);
                    value = (value >> GPIO_OFF(cmd)) & GPIO_MASK(cmd);
                    cmd = CMD_BUILD(m, c, value);
                    break;

                case SET_POWER:
                    if (PWR_UPDATE(cmd))
                    {
                        // turn on/off power to the specified modules
                        value = Xil_In32(XPAR_GPIO_0_BASEADDR);
                        value &= ~(0xF << 4);
                        value |= (PWR_MASK(cmd) << 4);
                        Xil_Out32(XPAR_GPIO_0_BASEADDR, value);
                    }
                    // read and return power status
                    value = Xil_In32(XPAR_GPIO_0_BASEADDR);
                    value = (value >> 4) & 0xF;
                    cmd = CMD_BUILD(m, c, value);
                    break;

                case GET_CURRENT:
                    value = backend_current_read(ADC_CH_MAP(CMD_MODULE_LOWER(cmd)));
                    cmd = CMD_BUILD(m, c, value);
                    break;

                default:
                    // forward the command to the indicated module
                    value = FRONTEND_FSL_PORT + CMD_MODULE_LOWER(cmd);
                    putdfslx(cmd, value, FSL_DEFAULT);
                    break;
            }
            // always provide an immediate response to the caller
            putfslx(cmd, BACKEND_FSL_PORT, FSL_DEFAULT);
		}

        volatile uint32_t frontend_value, frontend_invalid;
        for (uint32_t i = FRONTEND_FSL_PORT; i < XPAR_MICROBLAZE_0_FSL_LINKS; i++)
        {
            frontend_invalid = 1;
            getdfslx(frontend_value, i, FSL_NONBLOCKING);
            fsl_isinvalid(frontend_invalid);
            if (!frontend_invalid)
            {
                putfslx(frontend_value, BACKEND_FSL_PORT, FSL_DEFAULT);
            }
        }
	}

	return 0;
}
