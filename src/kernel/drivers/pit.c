#include <stdint.h>
#include <cpu/io.h>
#include <drivers/pit.h>
#include <cpu/interrupts.h>

#define CLOCKFREQ 1193182
#define TRUEMAX 65536
static volatile uint32_t ticks;

uint32_t pit_ticks(void){
    return ticks;
}

__attribute__((interrupt))
void pit_ih(struct interrupt_frame* frame){
    (void)frame;
    ticks++;
    outb(0x20,0x20);
}

void pit_init(uint32_t hz){
    if (hz == 0) return;

    // get 16-bit divisor
    uint32_t div = CLOCKFREQ / hz;

    // handle hardware limits and ensure the divisor fits in 16 bits    
    if (div > TRUEMAX) div = 0;
    if (div == 0) return;

    // set PIT up with [SET MODE 3 | CHANNEL 0 | ACCESS LO/HI]
    outb(0x43, 0x36);


    // send lo then hi to the out port
    outb(0x40, (uint8_t)(div & 0xFF));
    outb(0x40, (uint8_t)(div >> 8) & 0xFF);
}
