#include <lib/kprintf.h>
#include <stdarg.h>
#include <stdint.h>
#include <lib/itoa.h>
#include <drivers/console.h>

void kprintf(const char *fmt, ...){
    char buf[34];
    va_list args;

    va_start(args, fmt);


    for(int i=0; fmt[i] != '\0';i++){   
            
        if(fmt[i] != '%') {
            console_putchar(fmt[i]);
            continue;
        }

        char next = fmt[i+1];

         if(next == 's'){
             console_write(va_arg(args, const char *));
             i++;
         }
         else if(next == 'x'){
            uint32_t tmpval = va_arg(args, uint32_t);
            utoa(tmpval, buf, 16);
            console_write(buf);
            i++;
         }
         else if(next == 'c'){
            uint32_t tmpval = va_arg(args, uint32_t);
            char rchar = (char)tmpval;
            console_putchar(rchar);
            i++;
         }
         else if(next == 'u'){
            uint32_t tmpval = va_arg(args, uint32_t);
            utoa(tmpval, buf, 10);
            console_write(buf);
            i++;
         }
         else if(next == '%'){
            console_putchar('%');
            i++;
         }else {console_putchar('%');}
    }

    va_end(args);
}
