#include <xparameters.h>
#include <fsl.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_iic.h"
#include "custom_spi.h"
#include "custom_gpio.h"
#include "custom_intc.h"
#include "custom_timer.h"

#define TIME_60S ((uint64_t)6000000000)
#define TIME_30S ((uint64_t)3000000000)
#define TIME_10S ((uint64_t)1000000000)
#define TIME_1S  ((uint64_t)100000000)

void timer_handler() __attribute__((fast_interrupt));
void timer_handler()
{
    static uint8_t eth_on = 1;

    TIMER_INT_CLEAR();

    if (eth_on == 1)
    {
        *GPIO0 &= ~GPIO_STATUS_NET;
    }
    else
    {
        *GPIO0 |= GPIO_STATUS_NET;
    }

    eth_on = !eth_on;
    TIMER_INIT(TIME_60S);
}

int main()
{
    // Begin initialization

    microblaze_enable_interrupts();

    *GPIO0 &= ~(GPIO_SOFT_RST | GPIO_STATUS_NET | GPIO_STATUS_FPGA);
    *GPIO0 |= (GPIO_STATUS_NET | GPIO_STATUS_FPGA);
    TIMER_INT_CLEAR();

    SPI_RST();
    SPI_INIT();

    INTC_ENABLE(timer_handler);
    TIMER_INIT(TIME_60S);

    // End initialization

    uint8_t ch = 0;
    uint32_t vals[4] = {0};
    uint16_t current_adc_thresh = 1500;

	while(1)
	{
        // measure current on each loop

        vals[ch] = backend_current_read(ch);
        if (vals[ch] > current_adc_thresh)
        {
            // power off module in case of over-current
            MODULE_CLR_PWR(ch);
        }
        ch = (ch + 1) % 4;

        // check for command from workstation

        uint32_t cmd = 0;
        if (SPI_RX_VALID())
        {
            cmd = SPI_READ();
            TIMER_INIT(TIME_60S);
        }

        // handle commands

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
                    value = CMD_MODULE_LOWER(cmd);
                    CMD_SET_PAYLOAD(cmd, vals[value]);
                    break;

                case COUNTER_READ:
                    cmd = handle_counter(cmd);
                    break;

                case UPDATE_REG:
                    if (cmd >> 16 == 0) {
                        value = current_adc_thresh;
                        current_adc_thresh = cmd & 0xFFFF;
                        CMD_SET_PAYLOAD(cmd, value);
                        break;
                    };
                    // else fall through

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

            // Only send responses to the workstation if the
            // power should be on. Sometimes some invalid data
            // is generated when powering off the module
            if (!invalid && MODULE_PWR_IS_SET(i))
            {
                // frontend module indicates over-temperature
                if (CMD_COMMAND(value) == CMD_RESPONSE)
                {
                    // power off the specified module
                    MODULE_CLR_PWR(i);
                }
                else
                {
                    // forward frontend response to workstation
                    SPI_WRITE(value);
                }
            }
        }
	}

	return 0;
}
