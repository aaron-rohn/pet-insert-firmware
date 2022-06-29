#include <xparameters.h>
#include <fsl.h>
#include "command.h"
#include "frontend_iic.h"

extern uint8_t module_id;

volatile uint32_t temp_values[8] = {0};

// default temperature threshold is ~35C
uint16_t temp_adc_thresh = 0x3DC;

volatile unsigned long queue_size = 0;
uint32_t queue[QUEUE_SIZE_MAX];

/*
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
*/

cmd_t c = ADC_READ;
enum iic_state_t state = WRITE;
int adc_ch = 0, adc_addr = ADC0_ADDR, dac_ch = 0;
uint8_t buf[2] = {0,0};
const unsigned long n = sizeof(buf);

void handle_write()
{
    uint32_t cmd = 0;
    c = ADC_READ;
    if (QUEUE_NEMPTY())
    {
        cmd = QUEUE_POP();
        c = CMD_COMMAND(cmd);
    }

    uint8_t dac_cmd = 0;
    uint32_t dac_val = 0;

    switch(c)
    {
        case DAC_WRITE:

            dac_cmd = CMD_DAC_COMMAND(cmd);
            dac_ch  = CMD_DAC_CHANNEL(cmd);
            dac_val = CMD_DAC_VAL(cmd);

            // write the specified value to the DAC reg
            IIC_WR(IIC_start | (DAC_ADDR << 1) | IIC_write);
            IIC_WR((dac_cmd << 4) | dac_ch);
            IIC_WR((dac_val >> 8) & 0xFF);
            IIC_WR(IIC_stop | (dac_val & 0xFF));

        case DAC_READ:
            state = RD_TOP;
            break;

        default:
            adc_addr = adc_ch < 4 ? ADC0_ADDR : ADC1_ADDR;

            // start an ADC conversion
            IIC_WR(IIC_start | (adc_addr << 1) | IIC_write);
            IIC_WR(ADC_CONFIG_REG);
            IIC_WR(ADC_CONFIG_H | ((adc_ch % 4) << 4));
            IIC_WR(IIC_stop | ADC_CONFIG_L);

            state = WAIT_TOP;
    }
}

void handle_read_top()
{
    switch (c)
    {
        case DAC_WRITE:
        case DAC_READ:
            // read back DAC conversion value
            IIC_WR(IIC_start | (DAC_ADDR << 1) | IIC_write);
            IIC_WR(0x10 | dac_ch);
            IIC_WR(IIC_start | (DAC_ADDR << 1) | IIC_read);
            IIC_WR(IIC_stop  | n);
            break;

        default:
            // read back ADC conversion value
            IIC_WR(IIC_start | (adc_addr << 1) | IIC_write);
            IIC_WR(ADC_CONVERSION_REG);
            IIC_WR(IIC_start | (adc_addr << 1) | IIC_read);
            IIC_WR(IIC_stop  | n);
    }
}

void handle_read_bot()
{
    uint32_t value = (buf[0] << 4) | (buf[1] >> 4);

    switch(c)
    {
        case DAC_WRITE:
        case DAC_READ:
            value = CMD_BUILD(module_id, c, value);
            putfslx(value, 0, FSL_DEFAULT);
            break;

        default:
            temp_values[adc_ch] = value;
            if (value > temp_adc_thresh)
            {
                // send power off request to backend
                value = CMD_BUILD(module_id, CMD_RESPONSE, 0);
                putfslx(value, 0, FSL_DEFAULT);
            }
            adc_ch = (adc_ch + 1) % 8;
    }
}

void frontend_iic_handler()
{
    uint32_t status = *IIC_SR;
    uint32_t tx_empty = (status & IIC_SR_txfifoemp);
    uint32_t rx_empty = (status & IIC_SR_rxfifoemp);
    uint32_t nbytes = rx_empty ? 0 : (*IIC_RX_FIFO_OCY & 0xF) + 1;

    if (!tx_empty)
        goto err;

restart:

    switch (state)
    {
        case WRITE:
            IIC_BEGIN();
            handle_write();

            // jump to RD_TOP for DAC_READ
            if (c == DAC_READ)
                goto restart;

            break;

        case WAIT_TOP:
            // Read 2-byte control reg from ADC
            IIC_BEGIN();
            IIC_WR(IIC_start | (adc_addr << 1) | IIC_read);
            IIC_WR(IIC_stop  | n);
            state = WAIT_BOT;
            break;

        case WAIT_BOT:

            if (nbytes != n)
                goto err;

            // verify that conversion is done
            IIC_RD(buf, n);
            state = (buf[0] & ADC_CONFIG_OS) ? RD_TOP : WAIT_TOP;
            goto restart;

        case RD_TOP:
            IIC_BEGIN();
            handle_read_top();
            state = RD_BOT;
            break;

        case RD_BOT:

            if (nbytes != n)
                goto err;

            IIC_RD(buf, n);
            handle_read_bot();
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
