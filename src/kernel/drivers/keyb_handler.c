#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <drivers/keyb_handler.h>
#include <cpu/io.h>
#include <lib/kprintf.h>

#define MAX_LENGTH_SHELL_LINE 128
#define RELEASE_KEY_SC_MIN 0x80


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
    [0x0E] = '\b',
    [0x1C] = '\n',
    [0x0C] = '-',
    [0x0D] = '=',
    [0x0F] = '\t'
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
    [0x0E] = '\b',
    [0x1C] = '\n',
    [0x0C] = '_',
    [0x0D] = '+'

};

static bool debug = false;
static bool shifted = false;
static char line[MAX_LENGTH_SHELL_LINE];
static size_t line_len;
static volatile bool line_ready;

bool keyb_line_ready(void){
    return line_ready;
}
char *keyb_take_line(void){
    line_ready = false;
    line_len = 0;
    return line;
}

__attribute__((interrupt))
void keyboard_handler(struct interrupt_frame *frame){
   (void)frame;
   uint32_t sc = inb(0x60); 

    /* check if in debug and if so only print scan codes*/
    if(debug){
        if(sc < RELEASE_KEY_SC_MIN)kprintf("[P: %x]",sc);
        else kprintf("[R: %x]\n", sc);
    }

    /* check for shift */
    if (sc == 0x2a || sc == 0x36)           shifted = true;
    else if (sc == 0xAA || sc == 0xB6)      shifted = false;

    /* set current map based on shift state*/
    const char *current_map = shifted ? kmap_uppercase : kmap_lowercase; 
    
    if(!debug && sc < RELEASE_KEY_SC_MIN){
        char c = current_map[sc];
        if(c){
            if(c == '\n'){
                line[line_len] = '\0'; 
                line_ready = true;
                kprintf("\n");
            }else if(c == '\b'){
                if (line_len > 0) { line_len--; kprintf("\b"); }
            }else {
                if (line_len < MAX_LENGTH_SHELL_LINE){
                    line[line_len++] = c;
                    kprintf("%c", c);
                }
            }
        }
    }

    outb(0x20,0x20); /* send end of interrupt (EOI) to the PIC */
}
