#ifndef _CUSTOM_IIC_H_
#define _CUSTOM_IIC_H_

#include "types.h"

#define IIC_GIE          ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x01C)) // Global interrupt enable
#define IIC_ISR          ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x020)) // Interrupt status
#define IIC_IER          ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x028)) // Interrupt enable
#define IIC_SOFTR        ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x040)) // Soft reset
#define IIC_CR           ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x100)) // Control
#define IIC_SR           ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x104)) // Status
#define IIC_TX_FIFO      ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x108)) // TX FIFO
#define IIC_RX_FIFO      ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x10C)) // RX FIFO
#define IIC_ADR          ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x110)) // Slave address
#define IIC_TX_FIFO_OCY  ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x114)) // TX FIFO occupancy
#define IIC_RX_FIFO_OCY  ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x118)) // RX FIFO occupancy
#define IIC_TEN_ADR      ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x11C)) // Slave 10bit addr
#define IIC_RX_FIFO_PIRQ ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x120)) // RXFIFO programmable depth interrupt
#define IIC_GPO          ((volatile uint32_t*)(XPAR_AXI_IIC_0_BASEADDR + 0x110)) // General purpose output

#define IIC_GIE_gie      (1 << 31) // Enables all interrupts in the core, set this first

/*
 * Notes on handling interrupts:
 * 0: Clear CR_MSMS bit, then clear interrupt. Also see TX_FIFO reset bit
 * 1: Master TX - No slave was present at the address or slave accepts no more data.
 *    Master RX - Implies a transmit complete. Caused by setting the CR_TXAK bit to
 *                inidate that the last byte has been transmitted.
 *    This interrupt occurs before IIC4 (bus not busy) if both are set.
 * 2: Bit is set when a transmit throttle condition exists. Firmware can clear the bit
 *    only after the throttle is removed. See PG090 section on throttling for details.
 * 3: Set when RX fifo occupancy equals the programmable depth interrupt value. Data must
 *    be read before the interrupt can be cleared. This bit is not set at the same time as
 *    the transmit complete bit.
 * 4: Is set and cannot be cleared while the bus is not busy. Once SR_BB is asserted, this
 *    bit can be cleared.
 */

#define IIC_ISR0         (1 << 0) // Arbitration lost
#define IIC_ISR1         (1 << 1) // (TX) TX error / (RX) transmit complete
#define IIC_ISR2         (1 << 2) // TX FIFO empty
#define IIC_ISR3         (1 << 3) // RX FIFO full
#define IIC_ISR4         (1 << 4) // IIC bus not busy
#define IIC_ISR5         (1 << 5) // Addressed as slave
#define IIC_ISR6         (1 << 6) // Not addressed as slave
#define IIC_ISR7         (1 << 7) // TX FIFO half empty

#define IIC_ISR_DEFAULT (IIC_ISR4)

/*
 * Write the RKEY value to IIC_SOFTR to initiate a reset of the core
 */
#define IIC_SOFTR_RKEY   0xA

/*
 * Note on MSMS bit -- setting the bit creates a start condition in master mode.
 * Clearing the bit generates a stop condition and the interface switches to slave
 * mode.
 */

#define IIC_CR_gcen      (1 << 6) // Respond to general call address
#define IIC_CR_rsta      (1 << 5) // Repeated start
#define IIC_CR_txak      (1 << 4) // TX acknowledge enable
#define IIC_CR_tx        (1 << 3) // TX/RX mode select (TX = 1, RX = 0)
#define IIC_CR_msms      (1 << 2) // Master/Slave mode select
#define IIC_CR_txfiforst (1 << 1) // TX FIFO reset (following arb. lost or tx error)
#define IIC_CR_enable    (1 << 0) // IIC enable (set before anything else in CR)

#define IIC_SR_txfifoemp  (1 << 7) // TX fifo empty
#define IIC_SR_rxfifoemp  (1 << 6) // RX fifo empty
#define IIC_SR_rxfifofull (1 << 5) // RX fifo full
#define IIC_SR_txfifofull (1 << 4) // TX fifo full
#define IIC_SR_srw        (1 << 3) // When addressed as slave, indicates the R/W bit
#define IIC_SR_bb         (1 << 2) // Bus busy, set on start bit and cleared on stop bit
#define IIC_SR_aas        (1 << 1) // Addressed as slave
#define IIC_SR_abgc       (1 << 0) // Addressed by general call

/*
 * Note on TX FIFO -- if a dynamic stop bit is used and the IIC is a master receiver,
 * the value written to the TX FIFO is the number of bytes to receive.
 */

#define IIC_stop  (1 << 9) // Dynamic stop bit
#define IIC_start (1 << 8) // Dynamic start bit
#define IIC_read  (1 << 0) // Perform dynamic read
#define IIC_write (0 << 0) // Perform dynamic write

#define DAC_ADDR 0x4C
#define ADC_ADDR 0x48
#define ADC_CH_MAP(ch) ((uint8_t[]){1,0,3,2}[ch])

#define IIC_SUCCESS     0x0
#define IIC_ERR_TXERR   0x1
#define IIC_ERR_RXERR   0x2

#define IIC_WR(byte) ({ *IIC_TX_FIFO = (byte); })
#define IIC_RD(buf, n) ({\
        for (unsigned long i = 0; i < n; i++) buf[i] = *IIC_RX_FIFO;\
})

#define IIC_INIT(mask) ({\
    *IIC_SOFTR = IIC_SOFTR_RKEY;\
    *IIC_GIE = IIC_GIE_gie;\
    *IIC_IER = (mask);\
})

#define IIC_BEGIN() ({\
    *IIC_RX_FIFO_PIRQ = 0x0F;\
    *IIC_CR = IIC_CR_txfiforst;\
    *IIC_CR = IIC_CR_enable;\
})

enum iic_state_t {
    WRITE, 
    WAIT_TOP,
    WAIT_BOT,
    RD_TOP, 
    RD_BOT
};

uint8_t iic_write(uint8_t addr, uint8_t send_bytes, uint8_t *send_buf);
uint8_t iic_read(uint8_t addr, uint8_t send_bytes, uint8_t *send_buf, uint8_t recv_bytes, uint8_t *recv_buf);
//uint32_t backend_current_read(uint8_t ch);

void backend_iic_handler() __attribute__((fast_interrupt));

#endif
