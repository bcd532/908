#include <cpu/interrupts.h>
#include <drivers/console.h>


__attribute__((noreturn))
void exception_handler(void);
void exception_handler(){
    console_write("!! EXCEPTION HALT !!");
    __asm__ volatile ("cli; hlt");
    for(;;){};
}

