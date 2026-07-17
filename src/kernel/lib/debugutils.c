#include <lib/debugutils.h>
#include <stdint.h>
#include <drivers/console.h>



/* debugs the vga kernel console screen by filling up all the spaces using an incremental alphabetical order by row */
void dtl_KCONSOLE_FILL_SCREEN(uint8_t max_rows, uint8_t max_cols){
    /* disable scrolling and refresh console screen */
    console_enable_scroll(0);                       /* KNOWN BUG: when scroll is enabled you will always newline(); */
    console_clear();
    
    uint32_t cur_char = 'a';

    for(uint32_t row = 0; row < max_rows; row++){
        for(uint32_t col = 0; col < max_cols; col++){
           char str_buf[2] = { cur_char, '\0'}; /* make a string with the current character including a null terminator*/
           console_write(str_buf);
        }    
        if (cur_char < 'y')cur_char++; /* after a row of current character prints, ask, is the current character y?
                                          (past the 25th character in the alphabet)
                                          or vga height*/
    }}

