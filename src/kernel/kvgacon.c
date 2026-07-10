/* ============================================================================
 * console.c - VGA text-mode console implementation.
 * ==========================================================================*/
#include "console.h"
#include "mem.h"

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

void KCONSOLE_ENABLE_SCROLL(bool enable){
    scroll_enabled = enable;
}

/* Pack a character + colour into one VGA cell. */
static inline uint16_t cell(char c, uint8_t a) {
    return ((uint16_t)a << 8) | (uint8_t)c;
}

void KCONSOLE_SETCOLOR(uint8_t fg, uint8_t bg) {
    attr = (uint8_t)(fg | (uint8_t)(bg << 4));
}

void KCONSOLE_SETCURSOR(size_t row, size_t col){
    cur_row = row;
    cur_col = col;
}

void KCONSOLE_CLEAR(void) {
    for (size_t i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) vga[i] = cell(' ', attr);
    cur_row = 0;
    cur_col = 0;
}

void KCONSOLE_INIT(void) {
    KCONSOLE_SETCOLOR(VGA_WHITE, VGA_BLACK);
    KCONSOLE_CLEAR();
}

/* Move every visible row up by one and blank the bottom row. */
static void KCONSOLE_SCROLL(void) {
    memmove((void*)vga, (void*)(vga + VGA_WIDTH),(VGA_HEIGHT-1)* VGA_WIDTH * sizeof(*vga));
    for (uint32_t c = 0; c < VGA_WIDTH;c++)vga[(VGA_HEIGHT-1)*VGA_WIDTH + c] = cell(' ', attr);
}

/* Advance to the start of the next line, scrolling if we ran off the bottom. */
static void KCONSOLE_NEWLINE(void) {
    cur_col = 0;
    if (++cur_row == VGA_HEIGHT) {
        if(scroll_enabled){
        KCONSOLE_SCROLL();
        cur_row = VGA_HEIGHT - 1;
        }else cur_row = VGA_HEIGHT -1;
    }
}

/* The one primitive. Everything that prints goes through here, so wrapping,
 * scrolling and cursor tracking are defined in exactly one place. */
void CONSOLE_PUTCHAR(char c) {
    if (c == '\n') { KCONSOLE_NEWLINE(); return; }
    if (c == '\r') { cur_col = 0; return; }

    vga[cur_row * VGA_WIDTH + cur_col] = cell(c, attr);
    if (++cur_col == VGA_WIDTH)     /* ran off the right edge -> wrap */
        KCONSOLE_NEWLINE();
}

void KCONSOLE_WRITELEN(const char *s, size_t n) {
    for (size_t i = 0; i < n; i++)
        console_putchar(s[i]);
}

void KCONSOLE_WRITE(const char *s) {
    for (size_t i = 0; s[i] != '\0'; i++)
        console_putchar(s[i]);
}
