#ifndef IDT_H
#define IDT_H

#include <stdint.h>

void idt_set_descriptor(uint8_t vector, void* isr, uint8_t flags);

struct idt_entry_t{
    uint16_t isr;
    uint16_t kernel_cs;
    uint8_t ist;
    uint8_t attributes;
    uint16_t isr_offset;
} __attribute__((packed));


#endif
