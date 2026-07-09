#include "tests.h"
#include <stdint.h>
#include "console.h"

#define VGA_WIDTH 80
#define VGA_HEIGHT 25

void screen_fill_test(){
    console_enable_scroll(0);
    console_clear();
     
    uint32_t cur_char = 'a';


    for(uint32_t row = 0; row < VGA_HEIGHT; row++){
        for(uint32_t col = 0; col < VGA_WIDTH; col++){
        

           char str_buf[2] = { cur_char, '\0'};
           console_write(str_buf);
        }    
        if (cur_char < 'y')cur_char++;
    }}

