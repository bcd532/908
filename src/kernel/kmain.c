#include <stdint.h>
#include "console.h"


#define VGA_BUFFER ((volatile uint16_t *)0xb8000)



void kmain(void) {
    console_init();
    console_write("[ok] Kernel Loaded...");

    for (;;){}
}
