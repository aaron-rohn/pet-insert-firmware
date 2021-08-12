#ifndef _CUSTOM_UART_H_
#define _CUSTOM_UART_H_

#include <xparameters.h>
#include <xil_io.h>

#define UART_BASE XPAR_AXI_UARTLITE_0_BASEADDR

#define UART_RX     0x0
#define UART_TX     0x4
#define UART_STAT   0x8
#define UART_CTRL   0xC

#define UART_STAT_RX_VALID (1 << 0)
#define UART_STAT_RX_FULL  (1 << 1)
#define UART_STAT_TX_EMPTY (1 << 2)
#define UART_STAT_TX_FULL  (1 << 3)
#define UART_STAT_INTR_EN  (1 << 4)

#define UART_CTRL_TX_RST   (1 << 0)
#define UART_CTRL_RX_RST   (1 << 1)
#define UART_CTRL_INTR_EN  (1 << 4)

#define UART_WRITE(byte)    Xil_Out32(UART_BASE + UART_TX, byte)
#define UART_READ()         Xil_In32(UART_BASE + UART_RX)

#define UART_RX_VALID()     (Xil_In32(UART_BASE + UART_STAT) & UART_STAT_RX_VALID)
#define UART_TX_EMPTY()     (Xil_In32(UART_BASE + UART_STAT) & UART_STAT_TX_EMPTY)
#define UART_TX_FULL()      (Xil_In32(UART_BASE + UART_STAT) & UART_STAT_TX_FULL)

#define UART_RX_RST()       Xil_Out32(UART_BASE + UART_CTRL, UART_CTRL_RX_RST)
#define UART_TX_RST()       Xil_Out32(UART_BASE + UART_CTRL, UART_CTRL_TX_RST)
#define UART_TX_WAIT()      ({ while (!UART_TX_EMPTY()) ; })

#endif
