#include <xparameters.h>
#include <xil_io.h>
#include "custom_iic.h"
#include "custom_command.h"
#include "custom_spi.h"
#include "custom_gpio.h"

#define MODULE_RST_BIT (0x1 << 3)
#define MODULE_RST_ACK (0x1 << 0)

#define DAC_RST	0x70

int main()
{
    // Don't reset the DAC at start up
    // preserve the state of the air flow valve between resets
    uint8_t iic_write_buf[] = {0,0,0};

    GPIO_SET_FPGA_LED();

    SPI_RST();
    SPI_INIT();
    SPI_WRITE(0);

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
            SPI_WRITE(0);
        }
        else if (IS_CMD(cmd))
		{
            cmd_t c = CMD_COMMAND(cmd);
            uint32_t value = 0;

            switch (c)
            {
                case RST:
                    // set the reset bit
                    value = GPIO_RD_O();
                    GPIO_WR_O(value | MODULE_RST_BIT);

                    // wait for rst ack
                    do value = GPIO_RD_I();
                    while ((value & MODULE_RST_ACK) == 0);

                    // unset reset bit
                    value = GPIO_RD_O();
                    GPIO_WR_O(value & ~MODULE_RST_BIT);

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
            SPI_WRITE(0);
        }
    }

    return 0;
}
