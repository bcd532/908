#include <stdint.h>
#include "console.h"
#include "std9.h"
#include "tests.h"

#define VGA_BUFFER ((volatile uint16_t *)0xb8000)



void kmain(void) {
    console_init();
    console_write("[ok] Kernel Loaded...");
   // sleep_ms(1000);
    console_clear();
    console_set_cursor(5,0);
    console_write("Welcome to 908!");
    //sleep_ms(2000);
    screen_fill_test();
    

    for (;;){}
}
