#include "backend_timer.h"
#include "backend_gpio.h"

void timer_handler()
{
    static uint8_t eth_on = 1;

    TIMER_INT_CLEAR();

    if (eth_on == 1)
    {
        // ethernet is on -- turn it off
        *GPIO0 &= ~GPIO_STATUS_NET;
        TIMER_INIT(TIME_OFF);
    }
    else
    {
        // ethernet is off -- turn it on
        *GPIO0 |= GPIO_STATUS_NET;
        TIMER_INIT(TIME_ON);
    }

    eth_on = !eth_on;
}

