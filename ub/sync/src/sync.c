#include <xparameters.h>
#include <fsl.h>
#include "command.h"
#include "spi.h"
#include "sync_gpio.h"
#include "sync_iic.h"

int main()
{
    // Don't reset the DAC at start up
    // preserve the state of the air flow valve between resets
    uint8_t iic_write_buf[] = {0,0,0};

    *GPIO0 |= GPIO_STATUS_FPGA;

	while(1)
	{
        uint32_t cmd = 0, invalid = 1;
        getfslx(cmd, 0, FSL_NONBLOCKING);
        fsl_isinvalid(invalid);

        if (!invalid && IS_CMD(cmd))
        {
            enum cmd_t c = CMD_COMMAND(cmd);
            uint32_t value = 0;

            switch (c)
            {
                case RST:
                    // set the reset bit
                    *GPIO0 |= MODULE_RST_BIT;

                    // wait for rst ack
                    while ((*GPIO1 & MODULE_RST_ACK) == 0)
                        ;

                    // unset reset bit
                    *GPIO0 &= ~MODULE_RST_BIT;
                    cmd = CMD_EMPTY | 0x1;
                    break;

                case GPIO:
                    cmd = handle_gpio(cmd);
                    break;

                case DAC_WRITE:
                    value = CMD_DAC_VAL(cmd);
                    iic_write_buf[0] = 0x30; // write and update ch0
                    iic_write_buf[1] = (value >> 8) & 0xFF;
                    iic_write_buf[2] = (value >> 0) & 0xFF;
                    iic_write(DAC_ADDR, 3, iic_write_buf);

                    // Fall-through
                case DAC_READ:
                    iic_write_buf[0] = 0x10; // read back ch0
                    iic_write_buf[1] = 0;
                    iic_read(DAC_ADDR, 1, iic_write_buf, 2, iic_write_buf);

                    value = (iic_write_buf[0] << 4) | (iic_write_buf[1] >> 4);
                    cmd = CMD_BUILD(0, c, value);
                    break;

                default:
                    break;
            }

            putfslx(cmd, 0, FSL_DEFAULT);
        }
    }

    return 0;
}
