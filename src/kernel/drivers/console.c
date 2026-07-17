/* ============================================================================
 * console.c - VGA text-mode console implementation.
 * ==========================================================================*/
#include <drivers/console.h>
#include <lib/mem.h>

/* Single source of truth for the screen - defined ONCE, nowhere else. */
#define VGA_ADDR   0xB8000
static volatile uint16_t *const vga = (uint16_t *)VGA_ADDR;

/* extra vga params*/
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

/* All screen state lives here, and only here. */
static size_t   cur_row;     /* where the next character goes (the "cursor")  */
static size_t   cur_col;
static uint8_t  attr;        /* current colour byte (fg | bg << 4)      */


static bool scroll_enabled = true;

void console_enable_scroll(bool enable){
    scroll_enabled = enable;
}

/* Pack a character + colour into one VGA cell. */
static inline uint16_t cell(char c, uint8_t a) {
    return ((uint16_t)a << 8) | (uint8_t)c;
}

void console_setcolor(uint8_t fg, uint8_t bg) {
    attr = (uint8_t)(fg | (uint8_t)(bg << 4));
}

void console_setcursor(size_t row, size_t col){
    cur_row = row;
    cur_col = col;
}

int console_getcursor(char type){
    if (type == 'r')return cur_row;
    else if (type == 'c')return cur_col;
    else return 0;
}


void console_clear(void) {
    for (size_t i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) vga[i] = cell(' ', attr);
    cur_row = 0;
    cur_col = 0;
}

void console_init(void) {
    console_setcolor(VGA_WHITE, VGA_BLACK);
    console_clear();
}

/* Move every visible row up by one and blank the bottom row. */
static void console_scroll(void) {
    memmove((void*)vga, (void*)(vga + VGA_WIDTH),(VGA_HEIGHT-1)* VGA_WIDTH * sizeof(*vga));
    for (uint32_t c = 0; c < VGA_WIDTH;c++)vga[(VGA_HEIGHT-1)*VGA_WIDTH + c] = cell(' ', attr);
}

/* Advance to the start of the next line, scrolling if we ran off the bottom. */
static void console_newline(void) {
    cur_col = 0;
    if (++cur_row == VGA_HEIGHT) {
        if(scroll_enabled){
        console_scroll();
        cur_row = VGA_HEIGHT - 1;
        }else cur_row = VGA_HEIGHT -1;
    }
}

/* The one primitive. Everything that prints goes through here, so wrapping,
 * scrolling and cursor tracking are defined in exactly one place. */
void console_putchar(char c) {
    if (c == '\n') { console_newline(); return; }
    if (c == '\r') { cur_col = 0; return; }
    if (c == '\b') {
        if (cur_col > 0){
            cur_col--;
            vga[cur_row * VGA_WIDTH + cur_col] = cell(' ',attr);
        }
        else if (cur_row > 0){
            cur_row--;
            cur_col = VGA_WIDTH -1;
            vga[cur_row * VGA_WIDTH + cur_col] = cell(' ',attr);
        }
        return;
    }

    vga[cur_row * VGA_WIDTH + cur_col] = cell(c, attr);
    if (++cur_col == VGA_WIDTH)     /* ran off the right edge -> wrap */
        console_newline();
}

void console_writelen(const char *s, size_t n) {
    for (size_t i = 0; i < n; i++)
        console_putchar(s[i]);
}

void console_write(const char *s) {
    for (size_t i = 0; s[i] != '\0'; i++)
        console_putchar(s[i]);
}
