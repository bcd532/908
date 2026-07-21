#ifndef INTERRUPTS_H
#define INTERRUPTS_H

#include <stdint.h>

struct interrupt_frame{
    uint32_t eip;
    uint32_t cs;
    uint32_t eflags;

}__attribute__((packed));

#endif
