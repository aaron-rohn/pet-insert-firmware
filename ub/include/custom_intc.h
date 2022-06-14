#ifndef _CUSTOM_INTC_H_
#define _CUSTOM_INTC_H_

#include "xparameters.h"

#define INTC_BASE XPAR_AXI_INTC_0_BASEADDR

#define INTC_ISR ((volatile uint32_t*)(INTC_BASE + 0x00))
#define INTC_IPR ((volatile uint32_t*)(INTC_BASE + 0x04))
#define INTC_IER ((volatile uint32_t*)(INTC_BASE + 0x08))
#define INTC_IAR ((volatile uint32_t*)(INTC_BASE + 0x0C))
#define INTC_SIE ((volatile uint32_t*)(INTC_BASE + 0x10))
#define INTC_CIE ((volatile uint32_t*)(INTC_BASE + 0x14))
#define INTC_IVR ((volatile uint32_t*)(INTC_BASE + 0x18))
#define INTC_MER ((volatile uint32_t*)(INTC_BASE + 0x1C))
#define INTC_IMR ((volatile uint32_t*)(INTC_BASE + 0x20))
#define INTC_ILR ((volatile uint32_t*)(INTC_BASE + 0x24))

#define INTC_IVAR ((volatile unsigned long*)(INTC_BASE + 0x100))

#define INTC_ENABLE(handler) ({\
        *INTC_IMR  = 0x1;\
        *INTC_IVAR = ((unsigned long)(handler));\
        *INTC_IER  = 0x1;\
        *INTC_MER  = 0x3;\
})

#endif
