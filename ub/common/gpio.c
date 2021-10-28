#include <xparameters.h>
#include <xil_io.h>
#include "custom_command.h"
#include "custom_gpio.h"

uint32_t handle_gpio(uint32_t cmd)
{
    // read or write the two GPIO banks
    // Handles reset, power, LED, and status reading

    uint32_t value = 0;

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
    return cmd;
}
