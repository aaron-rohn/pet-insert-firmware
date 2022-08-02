#include "frontend_iic.h"

volatile uint32_t temp_values[ADC_NCH] = {0};
volatile uint16_t temp_thresh = TEMP_THRESH_DEFAULT;

#define QUEUE_SIZE_MAX 32
#define NEXT(val) ((val + 1) % QUEUE_SIZE_MAX)
volatile uint32_t queue[QUEUE_SIZE_MAX] = {0};
volatile uint32_t head = 0, tail = 0;

inline uint32_t queue_empty() { return head == tail; }
inline uint32_t queue_full() { return head == NEXT(tail); }

void queue_put(uint32_t val)
{
    if (!queue_full())
    {
        microblaze_disable_interrupts();
        queue[tail] = val;
        tail = NEXT(tail);
        microblaze_enable_interrupts();
    }
}

uint32_t queue_pop()
{
    uint32_t val = 0;
    if (!queue_empty())
    {
        val = queue[head];
        head = NEXT(head);
    }
    return val;
}

volatile enum cmd_t c = ADC_READ;
volatile enum iic_state_t state = WRITE;
volatile uint8_t ch = 0, addr = ADC0_ADDR;
volatile uint8_t rbuf[2] = {0};
const unsigned long n = sizeof(rbuf);

void handle_write()
{
    addr = (ch < 4) ? ADC0_ADDR : ADC1_ADDR;
    c = ADC_READ;

    uint32_t cmd = 0, dac_val = 0;
    uint8_t dac_cmd = 0, dac_ch = 0;

    if (!queue_empty())
    {
        cmd = queue_pop();
        c = CMD_COMMAND(cmd);

        dac_cmd = CMD_DAC_COMMAND(cmd);
        dac_ch  = CMD_DAC_CHANNEL(cmd);
        dac_val = CMD_DAC_VAL(cmd);
    }

    switch(c)
    {
        case DAC_WRITE:
            // write the specified value to the DAC reg
            IIC_WR(IIC_start | DAC_ADDR << 1 | IIC_write);
            IIC_WR((dac_cmd << 4) | dac_ch);
            IIC_WR((dac_val >> 8) & 0xFF);
            IIC_WR(IIC_stop | (dac_val & 0xFF));
            state = WRITE;
            break;

        case DAC_READ:
            // read back the specified DAC channel
            IIC_WR(IIC_start | DAC_ADDR << 1 | IIC_write);
            IIC_WR(0x10 | dac_ch);
            IIC_WR(IIC_start | DAC_ADDR << 1 | IIC_read);
            IIC_WR(IIC_stop  | n);
            state = RD_BOT;
            break;

        default:
            // start an ADC conversion
            IIC_WR(IIC_start | addr << 1 | IIC_write);
            IIC_WR(ADC_CONFIG_REG);
            IIC_WR(ADC_CONFIG_H | ((ch % 4) << 4));
            IIC_WR(IIC_stop | ADC_CONFIG_L);
            state = WAIT_TOP;
            break;
    }
}

void handle_read()
{
    uint32_t value = (rbuf[0] << 4) | (rbuf[1] >> 4);

    switch (c)
    {
        case DAC_READ:
            value = CMD_BUILD(module_id, c, value);
            putfslx(value, 0, FSL_DEFAULT);
            break;

        default:
            temp_values[ch] = value;

            // since we're using an NTC thermistor, the ADC code will go
            // down as temperature goes up. If the value drops below the
            // threshold, send a power off request
            if (value < temp_thresh)
            {
                value = CMD_BUILD(module_id, CMD_RESPONSE, 0);
                putfslx(value, 0, FSL_DEFAULT);
            }
            ch = (ch + 1) % ADC_NCH;
            break;
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
            break;

        case WAIT_TOP:
            // Read 2-byte control reg from ADC
            IIC_BEGIN();
            IIC_WR(IIC_start | addr << 1 | IIC_read);
            IIC_WR(IIC_stop  | n);
            state = WAIT_BOT;
            break;

        case WAIT_BOT:

            if (nbytes != n) goto err;

            // verify that conversion is done
            IIC_RD(rbuf, n);
            state = (rbuf[0] & ADC_CONFIG_OS) ? RD_TOP : WAIT_TOP;
            goto restart;

        case RD_TOP:
            // read back ADC conversion reg
            IIC_BEGIN();
            IIC_WR(IIC_start | addr << 1 | IIC_write);
            IIC_WR(ADC_CONVERSION_REG);
            IIC_WR(IIC_start | addr << 1 | IIC_read);
            IIC_WR(IIC_stop  | n);
            state = RD_BOT;
            break;

        case RD_BOT:

            if (nbytes != n) goto err;

            IIC_RD(rbuf, n);
            handle_read();
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
