#include "interrupts.h"
#include "kvgacon.h"


__attribute__((noreturn))
void exception_handler(void);
void exception_handler(){
    KCONSOLE_VGA_WRITE("!! EXCEPTION HALT !!");
    __asm__ volatile ("cli; hlt");
    for(;;){};
}

