/* advanced math library */
#include "advm.h"
#include <stdint.h>



int add(int32_t x, int32_t y){
    return x + y;
}

int divide(int32_t q, int32_t d){
    return q / d;
}

int divide_remainder(int32_t q, int32_t d){
    return q % d;
}

int mult(int32_t x, int32_t y){
    return x * y;

}
