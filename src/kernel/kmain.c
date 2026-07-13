#include <stdint.h>
#include <stdbool.h>
#include "mem.h"
#include "kvgaprintf.h"
#include "kvgacon.h"
#include "idt.h"
#include "advm.h"
#include "pic.h"
#include "keyb_handler.h"
#include "vs.h"

#define VGA_BUFFER ((volatile uint16_t *)0xb8000)

void handle_command(const char *cmd){
    if (strcmp(cmd, "help") == 0) kvgaprintf("commands: help, clear\n");
    else if (strcmp(cmd, "clear") == 0 ) KCONSOLE_VGA_CLEAR();
    else if (cmd[0] != '\0') kvgaprintf("unknown: %s\n", cmd);
}

void kmain(void) {
    /*initialize the idt and then point it to keyboard_handler for keyboard io */
    idt_init();
    idt_set_descriptor(0x21, keyboard_handler, 0x8E);
    
    /* remap the pic to prepare proper interrupts to handle*/
    pic_remap();

    KCONSOLE_VGA_INIT();
    __asm__ volatile("sti");
    kvgaprintf("(version %s - %s)\n", OS_VERSION_SNAME, OS_VERSION);
    KCONSOLE_VGA_WRITE("bsh/> ");
    for (;;){
        if (keyb_line_ready()) {
            char *cmd = keyb_take_line();
            handle_command(cmd);
            KCONSOLE_VGA_WRITE("bsh/> ");
        }
    }
}
