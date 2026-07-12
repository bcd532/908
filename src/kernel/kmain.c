#include <stdint.h>
#include "kvgacon.h"
#include "astdlib.h"
#include "debugutils.h"
#include "itoa.h"
#include "kvgaprintf.h"
#include "advm.h"

#define VGA_BUFFER ((volatile uint16_t *)0xb8000)

void kmain(void) {
    KCONSOLE_VGA_INIT();
    KCONSOLE_VGA_WRITE("[ OK ] ");
    for (;;){}
    }
