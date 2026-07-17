#include <lib/astdlib.h>
#include <stdint.h>
#include <cpu/io.h>

uint32_t segment_offset_to_linear(uint16_t segment, uint16_t offset){
    return ((uint32_t)segment << 4) + offset;
}

void sleep_ms(uint32_t ms){
    // 1.193182 Mhz / 1000 Hz = ~1193 ticks per ms
    uint16_t ticks_per_ms = 1193;

    while (ms--){
        // config PIT channel 0: mode 0 (interrupt on terminal count)
        // sending 0x30 sets access mode to low byte high byte
        outb(0x43, 0x30);

        // load the 16-bit countdown value into channel 0 (port 0x40)
        outb(0x40, (uint8_t)(ticks_per_ms & 0xFF));
        outb(0x40, (uint8_t)((ticks_per_ms >> 8) & 0xFF));

        // poll the PIT status command until the count hits 0
        // check the output pin status (bit 7) by sending a read-back command
        while(1){
            outb(0x43, 0xE2);
            uint8_t status = inb(0x40);
            if (status & 0x80){
                break;
            }
        }
    }
}
