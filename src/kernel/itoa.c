#include "itoa.h"
#include <stdint.h>
#include <stddef.h>

// unint to ascii
void utoa(uint32_t val, char *buf, int base){   

    int32_t i = 0;
    int32_t left = 0;
    while(val != 0){
        uint32_t remainder = val % base;
        val = val / base;
        buf[i] = "0123456789abcdef"[remainder];
        i++;
    }

    int32_t right = i -1;

    // reversal
    while(left < right){
        char tmp = buf[left];
        buf[left] = buf[right];
        buf[right] = tmp;
        left++;right--;
        
    }

    if(i == 0){ buf[i]= '0';i++;}
    
    buf[i] = '\0';

}
