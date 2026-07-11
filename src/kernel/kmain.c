#include <stdint.h>
#include "kvgacon.h"
#include "astdlib.h"
#include "debugutils.h"
#include "itoa.h"
#include "kprintf.h"


#define VGA_BUFFER ((volatile uint16_t *)0xb8000)
char dbg_S[] = "TEST";
char dbg_C = 'X';
uint32_t dbg_16b = 255;
uint32_t dbg_uint = 586;



void kmain(void) {
    KCONSOLE_VGA_INIT(); // initiate VGA console for writes
    KCONSOLE_VGA_WRITE("ok"); // ok
    kprintf("OUTPUT CHAR: %c\n", dbg_C);
    kprintf("OUTPUT STRING: %s\n", dbg_S);
    kprintf("OUTPUT HEX ADDRESS: %x\n", dbg_16b);
    kprintf("OUTPUT UINT32: %u\n", dbg_uint);
    kprintf("OUTPUT: 100%");
    
    KCONSOLE_VGA_SETCURSOR(9,9);
    KCONSOLE_VGA_WRITE("OK")    ;
    for (;;){}
}
