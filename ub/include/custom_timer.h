#ifndef _CUSTOM_TIMER_H_
#define _CUSTOM_TIMER_H_

#include "xparameters.h"
#include "types.h"

#define TIMER_BASE XPAR_AXI_TIMER_0_BASEADDR

#define TIMER_TCSR0 ((volatile uint32_t*)(TIMER_BASE + 0x00))
#define TIMER_TLR0  ((volatile uint32_t*)(TIMER_BASE + 0x04))
#define TIMER_TCR0  ((volatile uint32_t*)(TIMER_BASE + 0x08))

#define TIMER_TCSR1 ((volatile uint32_t*)(TIMER_BASE + 0x10))
#define TIMER_TLR1  ((volatile uint32_t*)(TIMER_BASE + 0x14))
#define TIMER_TCR1  ((volatile uint32_t*)(TIMER_BASE + 0x18))

#define TIMER_TCSR_CASC  (1 << 11)
#define TIMER_TCSR_ENALL (1 << 10)
#define TIMER_TCSR_PWMA  (1 << 9)
#define TIMER_TCSR_INT   (1 << 8)
#define TIMER_TCSR_ENT   (1 << 7)
#define TIMER_TCSR_ENIT  (1 << 6)
#define TIMER_TCSR_LOAD  (1 << 5)
#define TIMER_TCSR_ARHT  (1 << 4)
#define TIMER_TCSR_CAPT  (1 << 3)
#define TIMER_TCSR_GENT  (1 << 2)
#define TIMER_TCSR_UDT   (1 << 1)
#define TIMER_TCSR_MDT   (1 << 0)

#define TCSR0_DEFAULT (TIMER_TCSR_CASC | TIMER_TCSR_UDT | TIMER_TCSR_ENIT)

#define TIMER_INIT(value) ({\
        *TIMER_TCSR0 = 0; \
        *TIMER_TCSR1 = 0; \
        *TIMER_TLR0 = (value & 0xFFFFFFFF); \
        *TIMER_TLR1 = (value >> 32); \
        *TIMER_TCSR0 = TCSR0_DEFAULT; \
        *TIMER_TCSR0 |= TIMER_TCSR_LOAD;  \
        *TIMER_TCSR1 |= TIMER_TCSR_LOAD;  \
        *TIMER_TCSR0 &= ~TIMER_TCSR_LOAD; \
        *TIMER_TCSR1 &= ~TIMER_TCSR_LOAD; \
        *TIMER_TCSR0 |= TIMER_TCSR_ENT;   \
        })

#define TIMER_INT_CLEAR() ({ *TIMER_TCSR0 |= TIMER_TCSR_INT; })

#define TIME_60S ((uint64_t)6000000000)
#define TIME_30S ((uint64_t)3000000000)
#define TIME_10S ((uint64_t)1000000000)
#define TIME_1S  ((uint64_t)100000000)

void timer_handler() __attribute__((fast_interrupt));

#endif
