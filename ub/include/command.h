#ifndef _COMMAND_H_
#define _COMMAND_H_

#include <xparameters.h>
/*
 * Command structure: 32 bits
 *
 * 4'hF, 4'h{Module}, 4'h{Command}, 20'h{Payload}
 */

enum cmd_t {
    RST = 0,

    DAC_WRITE,      // frontend, 0x1
    ADC_READ,       // frontend, 0x2
    MODULE_ID,      // frontend, 0x3

    SET_POWER,      // backend, 0x4
    GET_CURRENT,    // backend, 0x5
    GPIO,           // backend, 0x6
    NOP,            // backend, 0x7

    DAC_READ,       // frontend, 0x8
    PERIOD_READ,    // frontend, 0x9
    SGL_RATE_READ,  // frontend, 0xA
    GPIO_FRONTEND,  // frontend, 0xB

    COUNTER_READ,   // backend, 0xC
    UPDATE_REG,     // backend or frontend, 0xD

    // indicate that a reply is pending from the frontend
    CMD_RESPONSE = 0xF
};

// General values

#define CMD_EMPTY 			 	0xF0000000
#define IS_CMD(cmd)             ((cmd >> 28) == 0xF)
#define CMD_COMMAND(cmd)        ((cmd >> 20) & 0xF)
#define CMD_MODULE(cmd)         ((cmd >> 24) & 0xF) // full 4 bit module, 0-15
#define CMD_MODULE_LOWER(cmd)   ((cmd >> 24) & 0x3) // lowest 2 bits, indicating the backend port
#define CMD_PAYLOAD(cmd)        (cmd & 0xFFFFF)
#define CMD_BUILD(m,c,p)        ( CMD_EMPTY | (((m) & 0xF) << 24) | (((c) & 0xF) << 20) | ((p) & 0xFFFFF) )
#define CMD_SET_PAYLOAD(cmd,pld) ({ cmd &= ~0xFFFFF; cmd |= (pld & 0xFFFFF); })

// DAC values

#define CMD_DAC_COMMAND(cmd)	((cmd >> 16) & 0xF)
#define CMD_DAC_CHANNEL(cmd)	((cmd >> 12) & 0xF)
#define CMD_DAC_VAL(cmd) 	    ((cmd & 0xFFF) << 4)
#define CMD_DAC_BUILD(cmd,ch,val) ((cmd << 16) | (ch << 12) | val)

// ADC values

#define CMD_ADC_CHANNEL(cmd)    ((cmd >> 16) & 0xF)

#define ADC_CONVERSION_REG      0x0
#define ADC_CONFIG_REG          0x1

#define ADC_CONFIG_OS           (1 << 7)
#define ADC_CONFIG_H            (ADC_CONFIG_OS | 1 << 6 | 0x2 << 1 | 1)
#define ADC_CONFIG_L            (0x3)

// Backend values

// payload: { 
// 15 bits: X, 
// 1 bit: read only (1) / write+read (0), 
// 4 bits: power mask }
#define PWR_UPDATE(cmd) ((cmd >> 4) & 0x1)
#define PWR_MASK(cmd)   (cmd & 0xF)

/*
 * payload: { 
 *  2 bits: RD/WR,
 *  2 bits: bank 0/1
 *  8 bits: offset, 
 *  4 bits: mask, 
 *  4 bits: value
 * }
 */
// Nonzero value in the top 4 bits specifies write, zero specifies read
#define GPIO_RW(cmd)    ((cmd >> 18) & 0x03)
#define GPIO_BANK(cmd)  ((cmd >> 16) & 0x03)
#define GPIO_OFF(cmd)   ((cmd >>  8) & 0xFF)
#define GPIO_MASK(cmd)  ((cmd >>  4) & 0x0F)
#define GPIO_VALUE(cmd) ((cmd >>  0) & 0x0F)

/*
 * Counter_read
 * 14 bits: X
 * 4  bits: counter divisor
 * 2  bits: counter select
 */

#define SEL_COUNTER(cmd) (cmd & 0x3)
#define COUNTER_DIVISOR(cmd) ((cmd >> 2) & 0xF)

#define UPDATE_REG_BACKEND(cmd) ((CMD_PAYLOAD(cmd) >> 16) == 0)
#define UPDATE_REG_FRONTEND(cmd) ((CMD_PAYLOAD(cmd) >> 16) != 0)

#endif
