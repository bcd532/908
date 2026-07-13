#include <stdint.h>
#include "idt.h"


extern void *isr_stub_table[];

/* Sets up a struct for the whole address of the IDTR */
typedef struct {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed)) idtr_t;

/* Initialize the IDTR statically to avoid it sitting on the temporary function stack (prevents stack corruption, undefined behavior
 * and guarantees absolute memory reference for the assembler) */
static idtr_t idtr; 

/**/ 
__attribute__((aligned(0x10))) /* forces the array to land on a 16-byte boundary to avoid cache line splits */
static struct idt_entry_t idt[256]; /* init 256 idt gates */


void idt_set_descriptor(uint8_t vector, void* isr, uint8_t flags){

    struct idt_entry_t* descriptor      = &idt[vector];                      /* sets up the descriptor for the given interrupt vector */

    descriptor->offset_s0e15            = (uint32_t)isr & 0xFFFF;            /* sets offset 1 (bits 0->15) to the given ISR's lower 16 bits */
    descriptor->selector                = 0x08;                              /* sets the selector to the code segment 0x08 */
    descriptor->zero_slot               = 0;                                 /* sets the zero slot */
    descriptor->attributes              = flags;                             /* sets the attributes to the given flags*/
    descriptor->offset_s16e31           = ((uint32_t)isr >> 16)& 0xFFFF;     /* sets offset 2 (bits 16->31) to the given ISR's upper 16 bits */
}



void idt_init(){
    idtr.limit = sizeof(idt) -1; /* table size in bytes minus 1*/
    idtr.base = (uint32_t)&idt;  /* sets the address to the idt descriptor */
    for (int v = 0; v < 32; v++) idt_set_descriptor(v, isr_stub_table[v], 0x8E);
    __asm__ volatile( "lidt %0"
                      : 
                      : "m"(idtr)); /* loads the idt at the given idt descriptor */

}
