#include <xparameters.h>
#include "command.h"
#include "frontend_iic.h"

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

uint32_t read_adc_temp(uint8_t channel)
{
    uint8_t buf[3] = {0};
    
    // ADC0 -> channels 0-3, ADC1 -> channels 4-7
    uint8_t adc_addr = channel < 4 ? ADC0_ADDR : ADC1_ADDR;
    // map system channel to ADC0/1 channel
    channel %= 4;

    // Initiate a conversion
    IIC_BUF_SET(buf, ADC_CONFIG_REG, ADC_CONFIG_H | (channel << 4), ADC_CONFIG_L);
    uint8_t iic_return = iic_write(adc_addr, 3, buf);

    // Wait until conversion finishes
    IIC_BUF_SET(buf, 0xFF,0,0);
    while (iic_return == IIC_SUCCESS && (buf[0] & ADC_CONFIG_OS) == 0)
    {
        iic_return = iic_read(adc_addr, 0, NULL, 2, buf);
    }

    // Read back conversion value
    IIC_BUF_SET(buf, ADC_CONVERSION_REG, 0, 0);
    iic_read(adc_addr, 1, buf, 2, buf);
    return (buf[0] << 4) | (buf[1] >> 4);
}

void dac_write(uint32_t cmd_buf)
{
    uint8_t buf[3] = {0};
    uint8_t dac_cmd = CMD_DAC_COMMAND(cmd_buf);
    uint8_t channel = CMD_DAC_CHANNEL(cmd_buf);
    uint32_t value  = CMD_DAC_VAL(cmd_buf);
    IIC_BUF_SET(buf, (dac_cmd << 4) | channel, (value >> 8) & 0xFF, value & 0xFF);
    iic_write(DAC_ADDR, 3, buf);
}

uint32_t dac_read(uint8_t channel)
{
    uint8_t buf[3] = {0};
    IIC_BUF_SET(buf, 0x10 | channel, 0, 0);
    iic_read(DAC_ADDR, 1, buf, 2, buf);
    return (buf[0] << 4) | (buf[1] >> 4);
}

void frontend_iic_handler()
{
}
