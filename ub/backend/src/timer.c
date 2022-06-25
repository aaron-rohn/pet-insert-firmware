#include "backend_timer.h"
#include "backend_gpio.h"

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

