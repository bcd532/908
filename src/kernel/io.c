#include "io.h"
#include <stdint.h>



inline void outb(uint16_t port, uint8_t val){
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}


inline uint8_t inb(uint16_t port){
    uint8_t r;
    __asm__ volatile ("inb %1, %0" : "=a"(r) : "Nd"(port));
    return r;
}
