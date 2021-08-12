#include <xparameters.h>
#include "custom_uart.h"

int uart_send_multi(const char *buf)
{
    int i = 0;
    while (buf[i] != '\0')
    {
        i += uart_write_bytes(buf + i);
    }
    return i;
}

int uart_write_bytes(const char *buf)
{
    int i = 0;
    while ((buf[i] != '\0') && (i < 16))
    {
        UART_WRITE(buf[i]);
        i++;
    }
    UART_TX_WAIT();
    return i;
}

static int n = 0;
int uart_recv_bytes(uint32_t *buf)
{
    while (UART_RX_VALID())
    {
        *buf = (*buf << 8) | UART_READ();
        n = (n + 1) % sizeof(*buf);
    }
    return n;
}
