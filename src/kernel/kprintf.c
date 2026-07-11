#include "kprintf.h"
#include <stdarg.h>
#include "itoa.h"
#include "kvgacon.h"

void kprintf(const char *fmt, ...){
    char buf[34];
    va_list args;

    va_start(args, fmt);


    for(int i=0; fmt[i] != '\0';i++){   
            
        if(fmt[i] != '%') {
            KCONSOLE_VGA_PUTCHAR(fmt[i]);
            continue;
        }

        char next = fmt[i+1];

         if(next == 's'){
             KCONSOLE_VGA_WRITE(va_arg(args, const char *));
             i++;
         }
         else if(next == 'd'){}
         else if(next == 'x'){}
         else if(next == 'c'){}
         else if(next == 'u'){}
         else if(next == '%'){}

        
    }
    va_end(args);

    

    
}
