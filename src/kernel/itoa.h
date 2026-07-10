#ifndef ITOA_H
#define ITOA_H
#include <stdint.h>

/* turns unsigned integer into a string using a given base
 *
 * buf must be at least 33 bytes (32 binary digits + '\0') */
void utoa(uint32_t val, char *buf, int base);

#endif 
