#include <cpu/io.h>
#include <stdint.h>

void pic_remap(void){
    uint8_t mask = 0xFC;
    outb(0x20, 0x11); /* begin initialization icw1 ->  command port*/
        outb(0xA0, 0x11);
    outb(0x21, 0x20); /* vector offset icw2 -> data port */
        outb(0xA1, 0x28);
    outb(0x21, 0x04); /* tells two chips how they're connected icw3 -> data port */
        outb(0xA1, 0x02);
    outb(0x21, 0x01); /* bit 0 */
        outb(0xA1, 0x01);
    outb(0x21, mask);
        outb(0xA1, mask);
}
