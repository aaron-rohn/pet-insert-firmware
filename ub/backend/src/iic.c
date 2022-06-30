#include <xparameters.h>
#include "command.h"
#include "backend_iic.h"
#include "backend_gpio.h"

volatile uint32_t current_values[4] = {0};
volatile uint32_t current_thresh = 1500;

void backend_iic_handler()
{
    static const uint8_t ch_map[4] = {1,0,3,2};
    static enum iic_state_t state = WRITE;
    static int ch = 0;
    static uint8_t buf[2] = {0,0};
    static const unsigned long n = sizeof(buf);

    uint32_t status = *IIC_SR;
    uint32_t tx_empty = (status & IIC_SR_txfifoemp);
    uint32_t rx_empty = (status & IIC_SR_rxfifoemp);
    uint32_t nbytes = rx_empty ? 0 : (*IIC_RX_FIFO_OCY & 0xF) + 1;

    if (!tx_empty) goto err;

restart:

    switch (state)
    {
        case WRITE:
            IIC_BEGIN();

            // start an ADC conversion
            IIC_WR(IIC_start | (ADC_ADDR << 1) | IIC_write);
            IIC_WR(ADC_CONFIG_REG);
            IIC_WR(ADC_CONFIG_H | (ch_map[ch] << 4));
            IIC_WR(IIC_stop | ADC_CONFIG_L);

            state = WAIT_TOP;
            break;

        case WAIT_TOP:
            IIC_BEGIN();

            // Read 2-byte control reg from ADC
            IIC_WR(IIC_start | (ADC_ADDR << 1) | IIC_read);
            IIC_WR(IIC_stop  | n);

            state = WAIT_BOT;
            break;

        case WAIT_BOT:

            if (nbytes != n) goto err;

            IIC_RD(buf, n);

            // verify that conversion is done
            state = (buf[0] & ADC_CONFIG_OS) ? RD_TOP : WAIT_TOP;
            goto restart;

        case RD_TOP:
            IIC_BEGIN();

            // read back conversion value
            IIC_WR(IIC_start | (ADC_ADDR << 1) | IIC_write);
            IIC_WR(ADC_CONVERSION_REG);
            IIC_WR(IIC_start | (ADC_ADDR << 1) | IIC_read);
            IIC_WR(IIC_stop  | n);

            state = RD_BOT;
            break;

        case RD_BOT:

            if (nbytes != n) goto err;

            IIC_RD(buf, n);
            current_values[ch] = (buf[0] << 4) | (buf[1] >> 4);

            if (current_values[ch] > current_thresh)
            {
                // shut off module due to over-current
                MODULE_CLR_PWR(ch);
            }

            ch = (ch + 1) % 4;
            state = WRITE;
            goto restart;
    }

    *IIC_ISR = *IIC_ISR;
    return;

err:

    IIC_INIT(IIC_ISR_DEFAULT);
    state = WRITE;
    goto restart;
}

