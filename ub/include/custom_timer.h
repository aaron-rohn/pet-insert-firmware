#ifndef _CUSTOM_TIMER_H_
#define _CUSTOM_TIMER_H_

#include "types.h"

#define TIMER_HALF_SECOND 0x2FAF080

#define TIMER_TCSR  ((volatile uint32_t*)(XPAR_AXI_TIMER_0_BASEADDR + 0x0))
#define TIMER_TLR   ((volatile uint32_t*)(XPAR_AXI_TIMER_0_BASEADDR + 0x4))
#define TIMER_TCR   ((volatile uint32_t*)(XPAR_AXI_TIMER_0_BASEADDR + 0x8))

#define TIMER_TCSR_INT  (1 << 8)
#define TIMER_TCSR_ENT  (1 << 7)
#define TIMER_TCSR_ENIT (1 << 6)
#define TIMER_TCSR_LOAD (1 << 5)
#define TIMER_TCSR_ARHT (1 << 4)
#define TIMER_TCSR_CAPT (1 << 3)
#define TIMER_TCSR_GENT (1 << 2)
#define TIMER_TCSR_UDT  (1 << 1)
#define TIMER_TCSR_MDT  (1 << 0)

#define TIMER_TCSR_DEFAULT (TIMER_TCSR_ENIT | TIMER_TCSR_UDT)

#define TIMER_START(value)                                  \
do {                                                        \
    *TIMER_TLR = (value);                      				\
    *TIMER_TCSR = TIMER_TCSR_DEFAULT | TIMER_TCSR_LOAD;     \
    *TIMER_TCSR = TIMER_TCSR_DEFAULT | TIMER_TCSR_ENT;      \
} while (0)

#define TIMER_STOP() (*TIMER_TCSR = TIMER_TCSR_DEFAULT)

#define TIMER_TIMEOUT_FRONTEND 0x186A0

#endif
