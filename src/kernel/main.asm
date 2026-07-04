bits 16
org 0x0000

start:
    cli
    call puts_print 


puts_print:
    mov ah, 0x0E
    mov al, 'K'
    mov bh, 0
    int 0x10

    hlt


.halt:
    hlt
    jmp .halt
