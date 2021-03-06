#include <xparameters.h>
#include <xil_io.h>
#include "command.h"
#include "spi.h"
#include "sync_gpio.h"
#include "sync_iic.h"

#define MODULE_RST_BIT (0x1 << 3)
#define MODULE_RST_ACK (0x1 << 0)

int main()
{
    // Don't reset the DAC at start up
    // preserve the state of the air flow valve between resets
    uint8_t iic_write_buf[] = {0,0,0};

    *GPIO0 |= GPIO_STATUS_FPGA;

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

            SPI_WRITE(cmd);
        }
    }

    return 0;
}
