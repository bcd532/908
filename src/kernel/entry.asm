bits 16

global start
extern kmain
extern __bss_start
extern __bss_end


start:
    cli
    xor ax, ax
    mov ds, ax
    
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    jmp CODE_SEG:init_pm


    
; ----------------------------------------------------------------------------
; Global Descriptor Table - flat model (base 0, limit 4 GB for both segments).
; Each descriptor is 8 bytes and the byte order is fixed by the CPU:
;   [limit 0-15][base 0-15][base 16-23][access][flags | limit 16-19][base 24-31]
; ----------------------------------------------------------------------------
gdtable:
    dq 0                    ; null descriptor

    ; 32-bit code segment
    dw 0xFFFF               ; limit  bits 0-15
    dw 0x0000               ; base   bits 0-15
    db 0x00                 ; base   bits 16-23
    db 10011010b            ; access: present, ring 0, code, executable, readable
    db 11001111b            ; flags:  G=4KB, 32-bit  + limit bits 16-19
    db 0x00                 ; base   bits 24-31

    ; 32-bit data segment
    dw 0xFFFF               ; limit  bits 0-15
    dw 0x0000               ; base   bits 0-15
    db 0x00                 ; base   bits 16-23
    db 10010010b            ; access: present, ring 0, data, writable
    db 11001111b            ; flags:  G=4KB, 32-bit  + limit bits 16-19
    db 0x00                 ; base   bits 24-31

gdt_descriptor:
    dw gdt_descriptor - gdtable - 1    ; limit: size of the table, minus 1
    dd gdtable                          ; base:  linear address of the table

; A selector is the descriptor's byte offset into the GDT (index << 3).
CODE_SEG equ 0x08
DATA_SEG equ 0x10


[bits 32]

init_pm:
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov esp, 0x90000

    cld
    mov edi, __bss_start
    mov ecx, __bss_end
    sub ecx, edi
    xor eax, eax
    rep stosb

    call kmain

.hang:
    cli
    hlt
    jmp .hang
