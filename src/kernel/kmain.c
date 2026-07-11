#include <stdint.h>
#include "kvgacon.h"
#include "astdlib.h"
#include "debugutils.h"
#include "itoa.h"
#include "kprintf.h"


#define VGA_BUFFER ((volatile uint16_t *)0xb8000)
char s[] = "bro";
void kmain(void) {
    KCONSOLE_VGA_INIT(); // initiate VGA console for writes
    KCONSOLE_VGA_WRITE("ok"); // ok
    kprintf("hello %s\n", s);
    
    KCONSOLE_VGA_WRITE("OK")    ;
    for (;;){}
}
