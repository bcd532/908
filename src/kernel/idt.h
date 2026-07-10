#ifndef IDT_H
#define IDT_H

#include <stdint.h>

void idt_set_descriptor(uint8_t vector, void* isr, uint8_t flags);

struct idt_entry_t{
    uint16_t offset_s0e15;               /* offset bits 0->15 */
    uint16_t selector;                   /* code segment selector */
    uint8_t zero_slot;                   /* unused, set to zero */                  
    uint8_t attributes;                  /* gate type, dpl, and p fields */
    uint16_t offset_s16e31;              /* offset bits 16->31 */
} __attribute__((packed));


#endif
