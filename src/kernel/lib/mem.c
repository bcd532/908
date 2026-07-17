#include <lib/mem.h>
#include <stddef.h>
#include <stdint.h>

void *memset(void *dst, int c, size_t n){
    unsigned char *d = (unsigned char *)dst;
    
    for(size_t i = 0; i < n; i++){
        d[i] = (unsigned char)c;
    }
    return dst;
}

void *memcpy(void *dst, const void *src, size_t n){
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;

    for(size_t i = 0; i < n; i++){
        d[i] = s[i];
    }
    return dst;
}

void *memmove(void *dst, const void *src, size_t n){
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;

    if (dst > src){ // copy backwards
        for (size_t i = n; i-- > 0;){
            d[i] = s[i];
        }}
    if (src > dst){ // copy forwards
        for (size_t i = 0; i < n; i ++){
            d[i] = s[i];
        }}

    return dst;
}

int memcmp(const void *a, const void *b, size_t n){
    const unsigned char *a_byte = (const unsigned char *)a;
    const unsigned char *b_byte = (const unsigned char *)b;


    for (size_t i = 0; i < n; i++){
        if (a_byte[i] != b_byte[i]){
            return (a_byte[i] - b_byte[i]);
        }
    }
    return 0;
}

size_t strlen(const char *s){
    size_t bytes = 0;
    while(s[bytes] != '\0') bytes++;
    return bytes;
}

int strcmp(const char *a, const char *b){
    const unsigned char* a_byte = (const unsigned char *)a;
    const unsigned char* b_byte = (const unsigned char *)b;
    size_t i = 0;
    while(a_byte[i] == b_byte[i] && a_byte[i] != '\0') i++;
    return a_byte[i] - b_byte[i];

}
