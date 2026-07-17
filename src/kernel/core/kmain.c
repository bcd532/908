#include <cpu/idt.h>
#include <drivers/pic.h>
#include <drivers/console.h>
#include <drivers/keyb_handler.h>
#include <core/shell.h>

void kmain(void) {
    /* interrupts: load the IDT, install the keyboard ISR at vector 0x21 */
    idt_init();
    idt_set_descriptor(0x21, keyboard_handler, 0x8E);

    /* remap the PIC so hardware IRQs land above the CPU exception vectors */
    pic_remap();

    /* bring up the console, enable interrupts, then hand off to the shell */
    console_init();
    __asm__ volatile("sti");
    shell_run();
}
