/* ============================================================================
 * console.h - VGA text-mode console (the kernel's screen output).
 *
 * Owns ALL screen state (cursor position, colour) in one place, and exposes a
 * single character primitive - console_putchar - that everything else composes
 * on. Handles newlines, line wrapping, and scrolling.
 * ==========================================================================*/
#ifndef CONSOLE_H
#define CONSOLE_H

// define global VGA txt params
#define VGA_TEXT_WIDTH  80
#define VGA_TEXT_HEIGHT 25

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

/* VGA text colours: low nibble = foreground, high nibble = background. */
enum vga_color {
    VGA_BLACK = 0, VGA_BLUE,        VGA_GREEN,       VGA_CYAN,
    VGA_RED,       VGA_MAGENTA,     VGA_BROWN,       VGA_LIGHT_GREY,
    VGA_DARK_GREY, VGA_LIGHT_BLUE,  VGA_LIGHT_GREEN, VGA_LIGHT_CYAN,
    VGA_LIGHT_RED, VGA_LIGHT_MAGENTA, VGA_YELLOW,    VGA_WHITE,
};


void KCONSOLE_VGA_PUTCHAR(char c);                          /* PRIMITIVE: Sets one character on the screen, catches right edge fall-off */

void KCONSOLE_VGA_INIT(void);                               /* sets kernel console color and clears screen */
void KCONSOLE_VGA_CLEAR(void);                              /* clears the screen of visible text and sets cursor to row 0, col 0 of the VGA console */
void KCONSOLE_VGA_SETCOLOR(uint8_t fg, uint8_t bg);         /* colour of subsequent output   */
void KCONSOLE_VGA_ENABLE_SCROLL(bool enable);               /* move visible row up by one and blank bottom row */
void KCONSOLE_VGA_WRITE(const char *s);                     /* null-terminated string        */
void KCONSOLE_VGA_WRITELEN(const char *s, size_t n);        /* explicit length               */
void KCONSOLE_VGA_SETCURSOR(size_t row, size_t col);

#endif /* CONSOLE_H */
