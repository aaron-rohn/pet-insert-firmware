#ifndef _CUSTOM_FIFO_H_
#define _CUSTOM_FIFO_H_

#include "types.h"

// AXI Stream fifo register space

#define FIFO_ISR(base_addr)  ((volatile uint32_t*)(base_addr + 0x00))
#define FIFO_IER(base_addr)  ((volatile uint32_t*)(base_addr + 0x04))

#define FIFO_TDFR(base_addr) ((volatile uint32_t*)(base_addr + 0x08)) // Tx reset
#define FIFO_TDFV(base_addr) ((volatile uint32_t*)(base_addr + 0x0C)) // Tx vacancy in words
#define FIFO_TDFD(base_addr) ((volatile uint32_t*)(base_addr + 0x10)) // Tx data port
#define FIFO_TLR(base_addr)  ((volatile uint32_t*)(base_addr + 0x14)) // Tx begin transmit length in bytes

#define FIFO_RDFR(base_addr) ((volatile uint32_t*)(base_addr + 0x18)) // Rx reset
#define FIFO_RDFO(base_addr) ((volatile uint32_t*)(base_addr + 0x1C)) // Number of locations occupied in rx fifo by latest packet
#define FIFO_RDFD(base_addr) ((volatile uint32_t*)(base_addr + 0x20)) // Rx data port
#define FIFO_RLR(base_addr)  ((volatile uint32_t*)(base_addr + 0x24)) // Number of bytes in the latest recieved packet

// Interrupt status bits

#define FIFO_ISR_RRC  (1 << 23)
#define FIFO_ISR_TRC  (1 << 24)
#define FIFO_ISR_RC   (1 << 26)
#define FIFO_ISR_TC   (1 << 27)

#define FIFO_TDFR_KEY 0xA5
#define FIFO_RDFR_KEY 0xA5

#endif
