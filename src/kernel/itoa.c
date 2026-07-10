#include "itoa.h"
#include <stdint.h>
#include <stddef.h>

/* convert an unsigned integer into a string using a given base
 * (e.g) utoa(908, buf, 10);  <- will push out 908 using base 10 */
void utoa(uint32_t val, char *buf, int base){   
    int32_t i = 0;
    int32_t left = 0;

    while(val != 0){
        uint32_t remainder = val % base;            /* put the remainder divided by the base into a temp var */
        val = val / base;                           /* make the given value now equal the quotient */
        buf[i] = "0123456789abcdef"[remainder];     /* a string lookup to find what the remainder equals to in asci (chars for addresses )
                                                            [a haha for me] we use ABCDE all the way to F because addresses cap their lettering at F*/
        i++;
    }

    /* Do a reversal with the given value by making the most significant number and the least significant number swap places until
    * they meet in the middle and are correctlyy placed */
    int32_t right = i-1;
    while(left < right){             
        char tmp = buf[left];      /* set a temp char to not overwrite & lose buf[left] when buf[right] has to become buf[left] */

        buf[left] = buf[right];          /* least significant digit swaps places with the most significant value */ 
        buf[right] = tmp;                /* buf[right] becomes buf[left] */

        left++;right--;                
    }

    /* since we're avoiding main loop when there's not an int given or a 0, we need to sill place a zero to avoid exiting program and increase 
     * the counter to place the null terminator if/when needed */
    if(i == 0){
        buf[i]= '0';
        i++;
    }
    
    buf[i] = '\0'; /* place null terminator at the end */

}
