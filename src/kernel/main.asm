; ============================================================================
; 908 kernel
; ============================================================================
; Loaded at physical 0x7E00 by the bootloader and entered in 16-bit real mode.
; It prints a boot banner via the BIOS, installs a flat GDT, switches the CPU
; into 32-bit protected mode, and then prints directly to VGA text memory.
;
; Addressing model: org 0x7E00 means every label IS its linear address, and we
; run with DS = 0. That keeps real mode and (flat, base-0) protected mode using
; one consistent address space, so the GDT base and far-jump targets just work.
; ============================================================================
bits 16
org 0x7E00

%define ENDL 0x0D, 0x0A         ; CR/LF, interpreted by BIOS teletype

; log_msg <prefix> <subject> <outcome> - print three strings via puts (BIOS).
%macro log_msg 3
    mov si, %1
    call puts
    mov si, %2
    call puts
    mov si, %3
    call puts
%endmacro

; ----------------------------------------------------------------------------
; 16-bit real-mode entry point (offset 0 = where the bootloader far-jumps to)
; ----------------------------------------------------------------------------

; start of program
start:
    cli
    xor ax, ax              ; DS = 0 so that DS:SI = the linear address of a label
    mov ds, ax

    log_msg p_ok, kern_load, o_pass     ; "[ok] KERNEL BOOT SUCCESSFUL"

    ; --- switch to 32-bit protected mode ---
    ; The GDT base stored below is already a linear address (org 0x7E00), so we
    ; load it directly - no runtime segment*16 + offset calculation is needed.
    lgdt [gdt_descriptor]   ; tell the CPU where our GDT lives
    mov eax, cr0
    or eax, 0x1             ; set PE (Protection Enable)
    mov cr0, eax
    jmp CODE_SEG:init_pm    ; far jump: reload CS from the GDT, flush the
                            ; pipeline, and continue in 32-bit code

; ----------------------------------------------------------------------------
; puts: print a null-terminated string using BIOS teletype (real mode only)
; Input:     DS:SI = pointer to the string
; Preserves: AX, SI
; ----------------------------------------------------------------------------
puts:
    push si
    push ax
.loop:
    lodsb                   ; AL = [DS:SI], SI++
    or al, al               ; AL == 0 ?
    jz .done
    mov ah, 0x0E            ; BIOS teletype function
    mov bh, 0               ; display page 0
    int 0x10
    jmp .loop
.done:
    pop ax
    pop si
    ret

; ----------------------------------------------------------------------------
; Real-mode data strings (BIOS teletype turns ENDL into a real newline)
; ----------------------------------------------------------------------------
p_ok      db "[ok] ", 0
p_err     db "[ERROR] ", 0
p_warn    db "[WARN] ", 0
kern_load db "KERNEL BOOT ", 0
s_disk    db "DISK READ ", 0
o_pass    db "SUCCESSFUL", ENDL, 0
o_fail    db "FAILED", ENDL, 0

; ----------------------------------------------------------------------------
; Global Descriptor Table - flat model (base 0, limit 4 GB for both segments).
; Each descriptor is 8 bytes and the byte order is fixed by the CPU:
;   [limit 0-15][base 0-15][base 16-23][access][flags | limit 16-19][base 24-31]
; ----------------------------------------------------------------------------
gdt_start:
    dq 0                    ; entry 0: null descriptor (required; 8 zero bytes)

gdt_code:                   ; entry 1: code segment  -> selector 0x08
    dw 0xFFFF               ; limit  bits 0-15
    dw 0x0000               ; base   bits 0-15
    db 0x00                 ; base   bits 16-23
    db 10011010b            ; access: present, ring 0, code, executable, readable
    db 11001111b            ; flags:  G=4KB, 32-bit  + limit bits 16-19
    db 0x00                 ; base   bits 24-31

gdt_data:                   ; entry 2: data segment  -> selector 0x10
    dw 0xFFFF               ; limit  bits 0-15
    dw 0x0000               ; base   bits 0-15
    db 0x00                 ; base   bits 16-23
    db 10010010b            ; access: present, ring 0, data, writable
    db 11001111b            ; flags:  G=4KB, 32-bit  + limit bits 16-19
    db 0x00                 ; base   bits 24-31
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; limit: size of the table, minus 1
    dd gdt_start                 ; base:  linear address of the table

; A selector is the descriptor's byte offset into the GDT (index << 3).
CODE_SEG equ gdt_code - gdt_start   ; = 0x08
DATA_SEG equ gdt_data - gdt_start   ; = 0x10


;
; ============================================================================
; 32-bit protected mode
; ============================================================================
;


[bits 32]

; PRINT_PM <string> <row> - print a null-terminated string to VGA text row <row>.
; <row> is a build-time constant, so the assembler computes the screen offset
; (160 bytes per row = 80 columns x 2 bytes per cell). No runtime multiply.
%macro PRINT_PM 2
    jmp %%skip                      ; step over the embedded string bytes
    %%text: db %1, 0
    %%skip:
    mov esi, %%text                 ; ESI = address of the string
    mov edi, 0xB8000 + (%2) * 160   ; EDI = first cell of row %2
    call f_print_pm
%endmacro

; init_pm: 32-bit entry. Reload every segment register from the GDT data
; segment, set up a stack in free memory, then run the kernel main.
init_pm:
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov ebp, 0x90000        ; stack top well above the kernel (kernel ends ~0x9E00)
    mov esp, ebp

    jmp kmain

; kmain: the 32-bit kernel main.
kmain:
    PRINT_PM "[ok] PROTECTED MODE SUCCESSFUL", 2
    jmp $                   ; nothing left to do - spin forever

; f_print_pm: write a null-terminated string to VGA text memory.
; Input: ESI = string, EDI = destination cell.  Attribute = 0x0F (white on black).
f_print_pm:
    mov ah, 0x0F            ; attribute byte (foreground/background colour)
.loop:
    lodsb                   ; AL = [ESI], ESI++
    or al, al
    jz .done
    mov [edi], ax           ; store character (AL) + attribute (AH)
    add edi, 2              ; advance to the next cell
    jmp .loop
.done:
    ret
