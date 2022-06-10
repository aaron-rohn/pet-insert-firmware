#ifndef _CUSTOM_INTC_H_
#define _CUSTOM_INTC_H_

#include "xparameters.h"

#define INTC_BASE XPAR_AXI_INTC_0_BASEADDR

#define INTC_ISR (INTC_BASE + 0x00)
#define INTC_IPR (INTC_BASE + 0x04)
#define INTC_IER (INTC_BASE + 0x08)
#define INTC_IAR (INTC_BASE + 0x0C)
#define INTC_SIE (INTC_BASE + 0x10)
#define INTC_CIE (INTC_BASE + 0x14)
#define INTC_IVR (INTC_BASE + 0x18)
#define INTC_MER (INTC_BASE + 0x1C)
#define INTC_IMR (INTC_BASE + 0x20)
#define INTC_ILR (INTC_BASE + 0x24)

#define INTC_IVAR (INTC_BASE + 0x100)

#define INTC_ENABLE(handler) ({\
        Xil_Out32(INTC_MER, 0x3);\
        Xil_Out32(INTC_IMR, 0x1);\
        Xil_Out32(INTC_IVAR, ((unsigned long)handler));\
        Xil_Out32(INTC_SIE, 0x1);\
})

#endif
