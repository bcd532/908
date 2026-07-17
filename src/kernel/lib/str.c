#include <lib/str.h>
#include <stdint.h>

uint32_t parse_uint(const char *s){
    uint32_t result = 0;
    int base = 10;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {base = 16; s +=2;}
    while (*s){
        char c = *s;
        int digit;
        if      (c >= '0' && c <= '9') digit = c - '0';
        else if (c >= 'a' && c <= 'f') digit = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') digit = c - 'A' + 10;
        else break;
        if (digit >= base) break;
        result = result * base + digit;
        s++;

        }
    return result;
    }
