#include <xparameters.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_spi.h"

int main()
{
    GPIO_SET_FPGA_LED();
    SPI_INIT();

    uint32_t cmd, cmd_valid, value;

	while(1)
	{
        cmd_valid = 0;
        if (SPI_RX_VALID())
        {
            cmd = SPI_READ();
            cmd_valid = (cmd >> 28 == 0xF);
        }

        if (cmd_valid)
		{
            SPI_TX_RST();
            
            switch (CMD_COMMAND(cmd)) {
                case RST:
                    // set the reset bit
                    value = GPIO_RD_O();
                    GPIO_WR_O(value | 0x1);

                    // wait for rst ack
                    do value = GPIO_RD_I();
                    while ((value & 0x1) == 0);

                    // unset reset bit
                    value = GPIO_RD_O();
                    GPIO_WR_O(value & ~0x1);

                    SPI_WRITE(CMD_EMPTY | 0x1);
                    break;

                default:
                    SPI_WRITE(CMD_EMPTY);
            }
        }
    }
    return 0;
}
