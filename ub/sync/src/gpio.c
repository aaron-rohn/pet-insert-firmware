#include <xparameters.h>
#include "command.h"
#include "sync_gpio.h"

uint32_t handle_gpio(uint32_t cmd)
{
    // read or write the two GPIO banks
    // Handles reset, power, LED, and status reading

    uint32_t value = 0;

    if (GPIO_RW(cmd))
    {
        // write to bank 0
        value = *GPIO0;
        value &= ~(GPIO_MASK(cmd) << GPIO_OFF(cmd));
        value |= (GPIO_MASK(cmd) & GPIO_VALUE(cmd)) << GPIO_OFF(cmd);
        *GPIO0 = value;
    }

    // read back from the specified bank
    value = *(GPIO_BANK(cmd) ? GPIO1 : GPIO0);
    value = (value >> GPIO_OFF(cmd)) & GPIO_MASK(cmd);

    CMD_SET_PAYLOAD(cmd, value);
    return cmd;
}
