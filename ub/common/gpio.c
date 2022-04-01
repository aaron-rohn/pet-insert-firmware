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

uint32_t handle_counter(uint32_t cmd)
{
    uint8_t module = CMD_MODULE_LOWER(cmd);
    uint8_t channel = SEL_COUNTER(cmd);

    uint32_t value = GPIO_RD_O();

    // clear module_select, channel_select, and channel_load
    value &= ~((0x3 << 8) | (0x3 << 10) | (0xF << 12));

    // set the module_select and channel_select values
    value |= ((module << 8) | (channel << 10));

    // write the select values and read the counter value
    GPIO_WR_O(value);
    uint32_t counter_val = GPIO_RD_I();

    // toggle the 'load' signal for the appropriate channel
    uint8_t channel_load_mask = 1 << channel;
    GPIO_WR_O(value | (channel_load_mask << 12));
    GPIO_WR_O(value);

    CMD_SET_PAYLOAD(cmd, counter_val);

    return cmd;
}
