#include <stdint.h>
#include "idt.h"

typedef struct {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed)) idtr_t;

static idtr_t idtr;
__attribute__((aligned(0x10)))

static idt_entry_t idt[256]; // create an array of idt entries

void idt_set_descriptor(uint8_t vector, void* isr, uint8_t flags);
void idt_set_descriptor(uint8_t vector, void* isr, uint8_t flags){
    idt_entry_t* descriptor = &idt[vector];

    descriptor->isr            = (uint32_t)isr & 0xFFFF;
    descriptor->kernel_cs      = 0x08;
    descriptor->ist            = 0;
    descriptor->attributes     = 0x8E;
descriptor->isr_offset         = (isr >> 16) & 0xFFFF;
}




