#ifndef KEYB_HANDLER_H
#define KEYB_HANDLER_H 

#include <stdint.h>

struct interrupt_frame{
    uint32_t eip;
    uint32_t cs;
    uint32_t eflags;

}__attribute__((packed));


void keyboard_handler(struct interrupt_frame *frame);

#endif
