#include <stdbool.h>

#include "keyb_handler.h"
#include "io.h"
#include "kvgaprintf.h"

static const char kmap_lowercase[128] = {

    /* number map*/
    [0x0B] = '0',
    [0x02] = '1',
    [0X03] = '2',
    [0x04] = '3',
    [0x05] = '4',
    [0x06] = '5',
    [0x07] = '6',
    [0x08] = '7',
    [0x09] = '8',
    [0x0A] = '9',

    /* char map */
    [0x1E] = 'a',
    [0x30] = 'b',
    [0x2E] = 'c',
    [0x20] = 'd',
    [0x12] = 'e',
    [0x21] = 'f',
    [0x22] = 'g',
    [0x23] = 'h',
    [0x17] = 'i',
    [0x24] = 'j',
    [0x25] = 'k',
    [0x26] = 'l',
    [0x32] = 'm',
    [0x31] = 'n',
    [0x18] = 'o',
    [0x19] = 'p',
    [0x10] = 'q',
    [0x13] = 'r',
    [0x1F] = 's',
    [0x14] = 't',
    [0x16] = 'u',
    [0x2F] = 'v',
    [0x11] = 'w',
    [0x2D] = 'x',
    [0x15] = 'y',
    [0x2C] = 'z',

    /* extra special map */
    [0x39] = ' ',
    [0x0E] = '\b'
};

static const char kmap_uppercase[128] = {

    /* number map (SHIFTED UP) */
    [0x02] = '!',
    [0X03] = '@',
    [0x04] = '#',
    [0x05] = '$',
    [0x06] = '%',
    [0x07] = '^',
    [0x08] = '&',
    [0x09] = '*',
    [0x0A] = '(',
    [0x0B] = ')',

    /* alphabet map (SHIFTED UP) */
    [0x1E] = 'A',
    [0x30] = 'B',
    [0x2E] = 'C',
    [0x20] = 'D',
    [0x12] = 'E',
    [0x21] = 'F',
    [0x22] = 'G',
    [0x23] = 'H',
    [0x17] = 'I',
    [0x24] = 'J',
    [0x25] = 'K',
    [0x26] = 'L',
    [0x32] = 'M',
    [0x31] = 'N',
    [0x18] = 'O',
    [0x19] = 'P',
    [0x10] = 'Q',
    [0x13] = 'R',
    [0x1F] = 'S',
    [0x14] = 'T',
    [0x16] = 'U',
    [0x2F] = 'V',
    [0x11] = 'W',
    [0x2D] = 'X',
    [0x15] = 'Y',
    [0x2C] = 'Z',

    /* extra special map */
    [0x39] = ' ',
    [0x0E] = '\b'

};

static bool debug = false;
static bool shifted = false;

__attribute__((interrupt))
void keyboard_handler(struct interrupt_frame *frame){
   (void)frame;
   uint32_t sc = inb(0x60); 

    /* check if in debug and if so only print scan codes*/
    if(debug){
        if(sc < 0x80)kvgaprintf("[P: %x]",sc);
        else kvgaprintf("[R: %x]\n", sc);
    }

    /* check for shift */
    if (sc == 0x2a || sc == 0x36)           shifted = true;
    else if (sc == 0xAA || sc == 0xB6)      shifted = false;

    /* set current map used based on special key*/
    const char *current_map = shifted ? kmap_uppercase : kmap_lowercase; 
    char c = current_map[sc];


    if(c) if (!debug && sc < 0x80) kvgaprintf("%c",c);

    outb(0x20,0x20); /* send end of instruction */
}
