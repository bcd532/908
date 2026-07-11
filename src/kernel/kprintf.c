#include "kprintf.h"
#include <stdarg.h>
#include <stdint.h>
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
         else if(next == 'x'){
            uint32_t tmpval = va_arg(args, uint32_t);
            utoa(tmpval, buf, 16);
            KCONSOLE_VGA_WRITE(buf);
            i++;
         }
         else if(next == 'c'){
            uint32_t tmpval = va_arg(args, uint32_t);
            char rchar = (char)tmpval;
            KCONSOLE_VGA_PUTCHAR(rchar);
            i++;
         }
         else if(next == 'u'){
            uint32_t tmpval = va_arg(args, uint32_t);
            utoa(tmpval, buf, 10);
            KCONSOLE_VGA_WRITE(buf);
            i++;
         }
         else if(next == '%'){
            KCONSOLE_VGA_PUTCHAR('%');
            i++;
         }else {KCONSOLE_VGA_PUTCHAR('%');}
    }

    va_end(args);
}
