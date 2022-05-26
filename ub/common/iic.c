#include <xparameters.h>
#include "custom_command.h"
#include "custom_iic.h"

uint8_t iic_write(uint8_t addr, uint8_t send_bytes, uint8_t *send_buf)
{
    *IIC_RX_FIFO_PIRQ = 0xF;
    *IIC_CR = IIC_CR_txfiforst;
    *IIC_CR = IIC_CR_enable;

    *IIC_TX_FIFO = IIC_TX_FIFO_start | (addr << 1) | IIC_TX_FIFO_write;
    for (uint8_t i = 1; i <= send_bytes; i++)
    {
        *IIC_TX_FIFO = send_buf[i-1] | (i == send_bytes ? IIC_TX_FIFO_stop : 0);
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
        *IIC_TX_FIFO = IIC_TX_FIFO_start | (addr << 1) | IIC_TX_FIFO_write;
        for (uint8_t i = 0; i < send_bytes; i++)
            *IIC_TX_FIFO = send_buf[i];
    }

    if (recv_bytes > 0)
    {
        // Read bytes from IIC device
        *IIC_TX_FIFO = IIC_TX_FIFO_start | (addr << 1) | IIC_TX_FIFO_read;
        *IIC_TX_FIFO = IIC_TX_FIFO_stop  | recv_bytes;
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

// Measure current consumption of one module each loop
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
