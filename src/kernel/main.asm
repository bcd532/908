bits 16
org 0x7E00

%define ENDL 0x0D, 0X0A


%macro log_msg 3
    mov si, %1
    call puts

    mov si, %2
    call puts
    
    mov si, %3
    call puts
%endmacro

start:
    cli
    mov ax, 0
    mov ds, ax

    log_msg p_ok, kern_load, o_pass
    
    jmp switch_to_pm

    hlt 

    

switch_to_pm:
    cli

    ; calculate real physical address of GDT
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, gdt_start

    mov [gdt_descriptor + 2], eax

    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 0x1
    mov cr0, eax

    jmp CODE_SEG:init_pm



gdt_start:
    dq 0    ; entry 0: null descriptor: 8 'zero' bytes [1 byte]
gdt_code:
    dw 0xFFFF                           ; Limit (bits 0-15)
    dw 0x0                              ; Base (bits 0-15)
    db 0x0                              ; Base(bits 16-23)
    db 10011010b                        ; Access byte (Present, Ring 0, Code, Readable)
    db 11001111b                        ; Flags (Granularity=4kb, 16-bit mode, Limit bits 16-19)
    db 0x0                              ; Base (bits 24-31)


gdt_data:
    dw 0xFFFF                           ; Limit (bits 0-15)
    dw 0x0                              ; Base (bits 0-15)
    db 0x0                              ; Base(bits 16-23)
    db 10010010b                        ; Access byte (Present, Ring 0, Data, Writable)
    db 11001111b                        ; Flags (Granularity=4kb, 16-bit mode, Limit bits 16-19)
    db 0x0                              ; Base(bits 24-31)

gdt_end:
     
gdt_descriptor:
    dw gdt_end - gdt_start - 1          ; size of the table minus 1
    dd gdt_start       ; adress of the table



puts:
    push si 
    push ax

.puts_loop:
    lodsb
    or al, al 
    jz .putsp_done

    mov ah, 0x0E
    mov bh, 0 
    int 0x10
    jmp .puts_loop

.putsp_done:
    pop ax
    pop si
    ret

; --- Status Prefixes ---
p_ok      db "[ok] ", 0
p_err     db "[ERROR] ", 0
p_warn    db "[WARN] ", 0

; --- Subsystems / Subjects ---
kern_load db "KERNEL BOOT ", 0
s_disk    db "DISK READ ", 0

; --- Outcomes / Suffixes ---
o_pass    db "SUCCESSFUL", ENDL, 0
o_fail    db "FAILED", ENDL, 0


CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

[bits 32]

init_pm:
    mov ax, DATA_SEG            ; update all segment registers with gdt data segment offset
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov ebp, 0x9000             ; put base stack pointer in a safe free mem area
    mov esp, ebp

    call BEGIN_PM

BEGIN_PM:
    mov byte [0xB8000], 'X'
    mov byte [0xB8001], 0x0F

    jmp $
