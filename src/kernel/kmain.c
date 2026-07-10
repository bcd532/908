#include <stdint.h>
#include "console.h"
#include "astdlib.h"
#include "tests.h"
#include "itoa.h"

#define VGA_BUFFER ((volatile uint16_t *)0xb8000)

void kmain(void) {
    console_init(); // initiate VGA console for writes
    console_write("ok"); // ok
    for (;;){}
}
