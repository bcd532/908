/* ============================================================================
 * console.h - VGA text-mode console (the kernel's screen output).
 *
 * Owns ALL screen state (cursor position, colour) in one place, and exposes a
 * single character primitive - console_putchar - that everything else composes
 * on. Handles newlines, line wrapping, and scrolling.
 * ==========================================================================*/
#ifndef CONSOLE_H
#define CONSOLE_H

#include <stdint.h>
#include <stddef.h>

/* VGA text colours: low nibble = foreground, high nibble = background. */
enum vga_color {
    VGA_BLACK = 0, VGA_BLUE,        VGA_GREEN,       VGA_CYAN,
    VGA_RED,       VGA_MAGENTA,     VGA_BROWN,       VGA_LIGHT_GREY,
    VGA_DARK_GREY, VGA_LIGHT_BLUE,  VGA_LIGHT_GREEN, VGA_LIGHT_CYAN,
    VGA_LIGHT_RED, VGA_LIGHT_MAGENTA, VGA_YELLOW,    VGA_WHITE,
};

void console_init(void);                                                     /* set default colour + clear   */
void console_clear(void);                                                    /* blank the screen, home cursor */
void console_set_color(uint8_t fg, uint8_t bg);                              /* colour of subsequent output  */

void console_putchar(char c);                                                /* THE primitive - one char     */
void console_write(const char *s);                                           /* null-terminated string       */
void console_write_endl(const char *s);                                      /* null-terminated & line ending string */
void console_write_len(const char *s, size_t n);                             /* explicit length              */

#endif /* CONSOLE_H */
