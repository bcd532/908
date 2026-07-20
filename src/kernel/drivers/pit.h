#ifndef PIT_H
#define PIT_H

#include <stdint.h>

struct interrupt_frame{
    uint32_t eip;
    uint32_t cs;
    uint32_t eflags;

}__attribute__((packed));

uint32_t pit_ticks(void);
void pit_ih(struct interrupt_frame* frame);
void pit_init(uint32_t hz);

#endif
