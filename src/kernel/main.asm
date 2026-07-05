bits 16
org 0x0000

%define ENDL 0x0D, 0X0A


%macro log_msg 3
    mov si, %1
    call puts

    mov si, %2
    call puts
    
    mov si, %3
    call puts
%endmacro

%define ENDL 0x0D, 0x0A
; --- Status Prefixes ---
p_ok      db "[ok] ", 0
p_err     db "[ERROR] ", 0
p_warn    db "[WARN] ", 0

; --- Subsystems / Subjects ---
kern_load db "KERNEL LOADING ", 0
s_disk    db "DISK READ ", 0

; --- Outcomes / Suffixes ---
o_pass    db "PASSED", ENDL, 0
o_fail    db "FAILED", ENDL, 0

start:
    cli
    mov ax, 0x07E0
    mov ds, ax

    log_msg p_ok, kern_load, o_pass
    
    hlt

     

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


.halt:
    hlt
    jmp .halt
