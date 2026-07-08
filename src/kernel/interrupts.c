#include "interrupts.h"

__atribute__((noreturn))
void exception_handler(void);
void exception_handler(){
    __asm__ volatile ("cli; hlt");
}