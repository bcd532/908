#ifndef PIT_H
#define PIT_H

#include <stdint.h>
#include <cpu/interrupts.h>

uint32_t pit_ticks(void);
void pit_ih(struct interrupt_frame* frame);
void pit_init(uint32_t hz);

#endif
