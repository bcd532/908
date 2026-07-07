/* ============================================================================
 * console.c - VGA text-mode console implementation.
 * ==========================================================================*/
#include "console.h"

/* Single source of truth for the screen - defined ONCE, nowhere else. */
#define VGA_ADDR   0xB8000
#define VGA_WIDTH  80
#define VGA_HEIGHT 25

static volatile uint16_t *const vga = (uint16_t *)VGA_ADDR;

/* All screen state lives here, and only here. */
static size_t  cur_row;     /* where the next character goes (the "cursor")  */
static size_t  cur_col;
static uint8_t attr;        /* current colour byte (fg | bg << 4)            */

/* Pack a character + colour into one VGA cell. */
static inline uint16_t cell(char c, uint8_t a) {
    return ((uint16_t)a << 8) | (uint8_t)c;
}

void console_set_color(uint8_t fg, uint8_t bg) {
    attr = (uint8_t)(fg | (uint8_t)(bg << 4));
}

void console_clear(void) {
    for (size_t i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++)
        vga[i] = cell(' ', attr);
    cur_row = 0;
    cur_col = 0;
}

void console_init(void) {
    console_set_color(VGA_WHITE, VGA_BLACK);
    console_clear();
}

/* Move every visible row up by one and blank the bottom row.
 * (Later this becomes memcpy/memset from libk; inline loops for now so the
 * console has no dependencies yet.) */
static void scroll(void) {
    for (size_t r = 1; r < VGA_HEIGHT; r++)
        for (size_t c = 0; c < VGA_WIDTH; c++)
            vga[(r - 1) * VGA_WIDTH + c] = vga[r * VGA_WIDTH + c];
    for (size_t c = 0; c < VGA_WIDTH; c++)
        vga[(VGA_HEIGHT - 1) * VGA_WIDTH + c] = cell(' ', attr);
}

/* Advance to the start of the next line, scrolling if we ran off the bottom. */
static void newline(void) {
    cur_col = 0;
    if (++cur_row == VGA_HEIGHT) {
        scroll();
        cur_row = VGA_HEIGHT - 1;
    }
}

/* The one primitive. Everything that prints goes through here, so wrapping,
 * scrolling and cursor tracking are defined in exactly one place. */
void console_putchar(char c) {
    if (c == '\n') { newline(); return; }
    if (c == '\r') { cur_col = 0; return; }

    vga[cur_row * VGA_WIDTH + cur_col] = cell(c, attr);
    if (++cur_col == VGA_WIDTH)     /* ran off the right edge -> wrap */
        newline();
}

void console_write_len(const char *s, size_t n) {
    for (size_t i = 0; i < n; i++)
        console_putchar(s[i]);
}

void console_write_endl(const char *s){
    for (size_t i = 0; s[i] != '\0'; i++){
    console_putchar(s[i]);
    }
    newline(); return;
}

void console_write(const char *s) {
    for (size_t i = 0; s[i] != '\0'; i++)
        console_putchar(s[i]);
}
