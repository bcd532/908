#ifndef STD9_H
#define STD9_H
#include <stdint.h>
uint32_t segment_offset_to_linear(uint16_t segment, uint16_t offset);
void sleep_ms(uint32_t ms);

#endif
