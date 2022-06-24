#include <xparameters.h>
#include "custom_command.h"
#include "custom_iic.h"
#include "custom_gpio.h"

volatile uint32_t current_values[4] = {0};
uint32_t current_thresh = 1500;

uint8_t iic_write(uint8_t addr, uint8_t send_bytes, uint8_t *send_buf)
{
    *IIC_RX_FIFO_PIRQ = 0xF;
    *IIC_CR = IIC_CR_txfiforst;
    *IIC_CR = IIC_CR_enable;

    *IIC_TX_FIFO = IIC_start | (addr << 1) | IIC_write;
    for (uint8_t i = 1; i <= send_bytes; i++)
    {
        *IIC_TX_FIFO = send_buf[i-1] | (i == send_bytes ? IIC_stop : 0);
    }

    while ((*IIC_SR & IIC_SR_bb) > 0)
        ; // wait

    uint8_t status = *IIC_SR;
    uint8_t tx_empty = (status & IIC_SR_txfifoemp);

    uint8_t ret = (!tx_empty) ? IIC_ERR_TXERR : IIC_SUCCESS;

    *IIC_CR = 0;

    // Encounterd some error... reset the IIC
    if (ret != IIC_SUCCESS) *IIC_SOFTR = IIC_SOFTR_RKEY;

    return ret;
}

uint8_t iic_read(
        uint8_t addr, 
        uint8_t send_bytes, uint8_t *send_buf, 
        uint8_t recv_bytes, uint8_t *recv_buf
) {
    // Initalize IIC controller
    *IIC_RX_FIFO_PIRQ = 0x0F;
    *IIC_CR = IIC_CR_txfiforst;
    *IIC_CR = IIC_CR_enable;

    if (send_bytes > 0)
    {
        // Send bytes to IIC device
        *IIC_TX_FIFO = IIC_start | (addr << 1) | IIC_write;
        for (uint8_t i = 0; i < send_bytes; i++)
            *IIC_TX_FIFO = send_buf[i];
    }

    if (recv_bytes > 0)
    {
        // Read bytes from IIC device
        *IIC_TX_FIFO = IIC_start | (addr << 1) | IIC_read;
        *IIC_TX_FIFO = IIC_stop  | recv_bytes;
    }

    while ((*IIC_SR & IIC_SR_bb) > 0)
        ; // wait

    uint8_t status = *IIC_SR;
    uint8_t tx_empty = (status & IIC_SR_txfifoemp);
    uint8_t rx_empty = (status & IIC_SR_rxfifoemp);
    uint8_t nbytes = rx_empty ? 0 : (*IIC_RX_FIFO_OCY & 0xF) + 1;

    for (uint8_t i = 0; i < nbytes && i < recv_bytes; i++)
        recv_buf[i] = *IIC_RX_FIFO;

    uint32_t ret = (!tx_empty)            ? IIC_ERR_TXERR   :
                   (nbytes != recv_bytes) ? IIC_ERR_RXERR   : IIC_SUCCESS;

    *IIC_CR = 0;

    if (ret != IIC_SUCCESS) *IIC_SOFTR = IIC_SOFTR_RKEY;

    return ret;
}

/*
uint32_t backend_current_read(uint8_t ch)
{
    uint8_t adc_ch = ADC_CH_MAP(ch);
    uint8_t buf[3] = {ADC_CONFIG_REG, ADC_CONFIG_H | (adc_ch << 4), ADC_CONFIG_L};
    uint8_t iic_return = iic_write(ADC_ADDR, sizeof(buf), buf);

    buf[0] = 0;
    buf[1] = 0;

    // wait until ADC conversion is complete
    while (iic_return == IIC_SUCCESS && (buf[0] & ADC_CONFIG_OS) == 0)
    {
        iic_return = iic_read(ADC_ADDR, 0, NULL, 2, buf);
    }

    if (iic_return == IIC_SUCCESS)
    {
        // Read back conversion value
        buf[0] = ADC_CONVERSION_REG;
        buf[1] = 0;
        iic_return = iic_read(ADC_ADDR, 1, buf, 2, buf);
    }

    return (buf[0] << 4) | (buf[1] >> 4);
}
*/

void backend_iic_handler()
{
    static enum iic_state_t state = WRITE;
    static int ch = 0;
    static uint8_t buf[2] = {0,0};
    const unsigned long n = sizeof(buf);

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
            IIC_WR(ADC_CONFIG_H | (ADC_CH_MAP(ch) << 4));
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

            // set pointer to conversion register
            IIC_WR(IIC_start | (ADC_ADDR << 1) | IIC_write);
            IIC_WR(ADC_CONVERSION_REG);

            // read back conversion value
            IIC_WR(IIC_start | (ADC_ADDR << 1) | IIC_read);
            IIC_WR(IIC_stop  | n);

            state = RD_BOT;
            break;

        case RD_BOT:

            if (nbytes != n) goto err;

            IIC_RD(buf, n);
            current_values[ch] = (buf[0] << 4) | (buf[1] >> 4);

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

