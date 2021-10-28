#include <xparameters.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_spi.h"
#include "custom_gpio.h"

#define MODULE_RST_BIT (0x1 << 3)
#define MODULE_RST_ACK (0x1 << 0)

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
            SPI_WRITE(0);

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

                default:
                    break;
            }

            SPI_WRITE(cmd);
        }
    }

    return 0;
}
