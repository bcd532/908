#include <stdint.h>
#include "kvgacon.h"
#include "astdlib.h"
#include "debugutils.h"
#include "itoa.h"
#include "kvgaprintf.h"
#include "idt.h"
#include "advm.h"

#define VGA_BUFFER ((volatile uint16_t *)0xb8000)

void kmain(void) {
    idt_init();
    KCONSOLE_VGA_INIT();
    kvgaprintf("[ OK ]\n")
    kvgaprintf("b4 exception\n");
    __asm__ volatile ("int 32");
    kvgaprintf("after (should not show)\n");
    for (;;){}
    }
