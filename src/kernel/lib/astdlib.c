#include <lib/astdlib.h>
#include <stdint.h>
#include <drivers/pit.h>

uint32_t segment_offset_to_linear(uint16_t segment, uint16_t offset){
    return ((uint32_t)segment << 4) + offset;
}

void sleep_ms(uint32_t ms){
    uint32_t start = pit_ticks();
    while (pit_ticks() - start < ms/10)
        __asm__ volatile("hlt");
}
