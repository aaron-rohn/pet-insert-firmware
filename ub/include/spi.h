#ifndef _CUSTOM_SPI_H_
#define _CUSTOM_SPI_H_

#include <xil_io.h>

#define SPI_BASE XPAR_SPI_0_BASEADDR

#define SPI_SRR     0x40
#define SPI_CR      0x60
#define SPI_SR      0x64
#define SPI_TX      0x68
#define SPI_RX      0x6C
#define SPI_SS      0x70
#define SPI_TX_OCC  0x74
#define SPI_RX_OCC  0x78
#define SPI_IER     0x1C
#define SPI_ISR     0x20

#define SPI_RST() Xil_Out32(SPI_BASE + SPI_SRR, 0xA)

#define SPI_CR_EN       (1 << 1)
#define SPI_CR_MASTER   (1 << 2)
#define SPI_CR_CPOL     (1 << 3)
#define SPI_CR_CPHA     (1 << 4)
#define SPI_CR_TX_RST   (1 << 5)
#define SPI_CR_RX_RST   (1 << 6)
#define SPI_CR_USE_SSR  (1 << 7)
#define SPI_CR_MTI      (1 << 8)
#define SPI_CR_LSB      (1 << 9)

#define SPI_SR_RX_EMP   (1 << 0)
#define SPI_SR_RX_FUL   (1 << 1)
#define SPI_SR_TX_EMP   (1 << 2)
#define SPI_SR_TX_FUL   (1 << 3)

#define SPI_IER_EN(en) Xil_Out32(SPI_BASE + SPI_IER, (en << 31))

// these bits are toggle on write
#define SPI_ISR_TX_EMP      (1 << 2)
#define SPI_ISR_TX_UNDERRUN (1 << 3)
#define SPI_ISR_SS          (1 << 7)
#define SPI_ISR_RX_VALID    (1 << 8)

#endif
