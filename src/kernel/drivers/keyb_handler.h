#ifndef KEYB_HANDLER_H
#define KEYB_HANDLER_H 

#include <stdint.h>
#include <cpu/interrupts.h>

void keyboard_handler(struct interrupt_frame *frame);
bool keyb_line_ready(void);
char *keyb_take_line(void);


#endif
