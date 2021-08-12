#ifndef _CUSTOM_COMMAND_H_
#define _CUSTOM_COMMAND_H_

/*
 * Command structure: 32 bits
 *
 * 4'hF, 4'h{Module}, 4'h{Command}, 20'h{Payload}
 */

typedef enum {
    RST = 0,

    // frontend commands
    DAC_WRITE,
    ADC_READ,
    MODULE_ID,

    // backend commands
    SET_POWER,
    GET_CURRENT,
    GPIO,
    NOP
} cmd_t;

// General values

#define CMD_EMPTY 			 	0xF0000000
#define CMD_COMMAND(cmd)        ((cmd >> 20) & 0xF)
#define CMD_MODULE(cmd)         ((cmd >> 24) & 0xF) // full 4 bit module, 0-15
#define CMD_MODULE_LOWER(cmd)   ((cmd >> 24) & 0x3) // lowest 2 bits, indicating the backend port
#define CMD_PAYLOAD(cmd)        (cmd & 0xFFFFF)
#define CMD_BUILD(m,c,p)        ( CMD_EMPTY | ((m & 0xF) << 24) | ((c & 0xF) << 20) | (p & 0xFFFFF) )

// DAC values

#define CMD_DAC_COMMAND(cmd)	((cmd >> 16) & 0xF)
#define CMD_DAC_CHANNEL(cmd)	((cmd >> 12) & 0xF)
#define CMD_DAC_VAL(cmd) 	    ((cmd & 0xFFF) << 4)

// ADC values

#define CMD_ADC_CHANNEL(cmd)    ((cmd >> 16) & 0xF)

#define ADC_CONVERSION_REG      0x0
#define ADC_CONFIG_REG          0x1

#define ADC_CONFIG_OS           (1 << 7)
#define ADC_CONFIG_H            (ADC_CONFIG_OS | 1 << 6 | 0x2 << 1 | 1)
#define ADC_CONFIG_L            (0x7 << 5 | 0x3)

// Backend values

// payload: { 
// 15 bits: X, 
// 1 bit: read only (1) / write+read (0), 
// 4 bits: power mask }
#define PWR_UPDATE(cmd) ((cmd >> 4) & 0x1)
#define PWR_MASK(cmd)   (cmd & 0xF)

// payload: { 4 bits: X, 8 bits: offset, 8 bits: mask }
#define GPIO_OFF(cmd)   ((cmd >> 8) & 0xFF)
#define GPIO_MASK(cmd)  (cmd & 0xFF)

#endif
