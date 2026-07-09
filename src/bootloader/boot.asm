; ============================================================================
; Bootloader for a FAT12 floppy image
; ============================================================================
;
; This file is a 512-byte boot sector. It contains the FAT12 BIOS Parameter
; Block (BPB) and Extended Boot Record (EBR), followed by the bootloader code.
; The BIOS loads this sector at 0x7C00 and begins execution at the first byte.

; 
org 0x7C00 ; bios mandates that the boot sector loads at physical address 0x7C00
bits 16 ; sends signal to NASM that says "GIVE THE CPU 16 BIT CODE"



; ----------------------------------------------------------------------------
; Macros
; ----------------------------------------------------------------------------
%define ENDL 0x0D, 0x0A ; END LINE MACRO
%define SECTOR_COUNT 64 ; SECTOR_COUNT (how many bytes to load (SECTOR_COUNT*512b))

; Skip the BIOS parameter block (BPB)
jmp short start ; before we can load the bpb, we need to store the drive number and initalize the stack
nop ; adds an offset to properly load bpb at offset 0x03


; ----------------------------------------------------------------------------
; FAT12 BIOS Parameter Block (BPB)
; ----------------------------------------------------------------------------
; This section is metadata, not code. The CPU does not execute it directly.
; The first instruction at the top jumps over this data and into the boot code.
; ----------------------------------------------------------------------------

bdb_oem:                        db 'MSQIN4.1'           ; 8-byte OEM identifier
bdb_bytes_per_sector:           dw 512                  ; sector size in bytes
bdb_sectors_per_cluster:        db 1                    ; sectors per allocation cluster
bdb_reserved_sectors:           dw 1                    ; reserved sectors before FAT
bdb_fat_count:                  db 2                    ; number of FAT copies
bdb_dir_entries_count:          dw 0E0h                 ; number of root entries
bdb_total_sectors:              dw 2880                 ; total number of sectors
bdb_media_descriptor_type:      db 0F0h                 ; media descriptor for floppy
bdb_sectors_per_fat:            dw 9                    ; sectors used by each FAT
bdb_sectors_per_track:          dw 18                   ; sectors per track
bdb_heads:                      dw 2                    ; number of heads (sides)
bdb_hidden_sectors:             dd 0                    ; hidden sectors before partition
bdb_large_sector_count:         dd 0                    ; large sector count (unused for floppy)

; ----------------------------------------------------------------------------
; Extended Boot Record (EBR)
; ----------------------------------------------------------------------------
ebr_drive_number:               db 0                    ; BIOS drive number (floppy = 0x00)
ebr_reserved:                   db 0                    ; reserved byte
ebr_boot_signature:             db 29h                  ; extended boot signature
ebr_volume_id:                  db 0h, 9h, 0h, 8h       ; unique 4-byte volume ID
ebr_volume_label:               db 'NINE ZERO 8'        ; volume label (11 chars)
ebr_system_id:                  db 'FAT12   '           ; filesystem type (8 chars)


; ----------------------------------------------------------------------------
; Bootloader code
; ----------------------------------------------------------------------------
start:
    jmp main    
    nop


; ---------------------------------------------------------------------------
; check_a20: report whether the A20 line is enabled, preserving all registers.
; It writes to a low address and its 1 MB-wrapped alias; if the alias changed
; too, addresses wrapped and A20 is off.
; Returns: AX = 0 if A20 is disabled, AX = 1 if A20 is enabled.
; ---------------------------------------------------------------------------
check_a20:
    pushf
    push ds 
    push es 
    push di
    push si

    cli

    mov di, 0x0500
    mov si, 0x0510

    xor ax, ax
    mov es, ax

    not ax
    mov ds, ax

    mov al, byte [es:di]
    push ax

    mov al, byte [ds:si]
    push ax

    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF

    cmp byte [es:di], 0xFF

    pop ax
    mov byte [ds:si], al 

    pop ax
    mov byte[es:di], al

    mov ax, 0
    je check_a20_exit

    mov ax, 1 
    jmp check_a20_exit



check_a20_exit:
    pop si
    pop di
    pop es
    pop ds
    popf

    ret


; ---------------------------------------------------------------------------
; main: bootloader entry point
; ---------------------------------------------------------------------------
main:
    ; Initialize segment registers for simple memory access.
    mov ax, 0
    ; we can't set constant data to segment registers so we set ax to 0 to then set the segment registers to ax
    mov ds, ax 
    mov es, ax

    ; Initialize stack.
    mov ss, ax
    mov sp, 0x7C00

    ; Store the BIOS drive number into the boot sector metadata.
    ; This proves the drive number is available in DL.
    mov [ebr_drive_number], dl

    ; Load the kernel from the first data sector into memory at 0x7E00.
    mov ax, 33              ; LBA 33 = first data sector (where kernel.bin lives)
    mov cl, SECTOR_COUNT    ; Reads up to the sector count (sector_count x 512b)
    mov bx, 0x7E00          ; 0x7e00 = first byte after the boot ends
    call disk_read

    call check_a20
    cmp ax, 1
    je .a20_ok

    call enable_a20
    call check_a20
    cmp ax, 1               ; check if a20 passed
    jne a20_failed         ; if ax != 1, jump to failure block

.a20_ok:
    jmp 0x0000:0x7E00       ; hand off to the kernel loaded at 0x7E00

; ---------------------------------------------------------------------------
; enable_a20: ask the BIOS to turn the A20 line on (INT 15h, AX=2401h).
; ---------------------------------------------------------------------------
enable_a20:
    mov ax, 0x2401
    int 0x15
    ret

; ---------------------------------------------------------------------------
; Error handlers: print a message, then wait for a key and halt.
; ---------------------------------------------------------------------------
floppy_error:
    jmp wait_key_and_reboot

a20_failed:
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 0x16                ; wait for a keypress
    hlt

; ----------------------------------------------------------------------------
; Disk helper routines
; ----------------------------------------------------------------------------

; lba_to_chs: convert LBA to CHS for BIOS disk access
; Input: AX = LBA
; Output: CH = cylinder low 8 bits
;         CL = sector (bits 0-5) + cylinder high bits (bits 6-7)
;         DH = head
; Clobbers: AX, CX, DX
; Preserves: original DL
lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track] ; AX = LBA / sectors_per_track, DX = remainder
    inc dx                            ; sector number is 1-based
    mov cx, dx                        ; CX = sector

    xor dx, dx
    div word [bdb_heads]              ; AX = cylinder, DX = head
    mov dh, dl                        ; DH = head
    mov ch, al                        ; CH = cylinder low byte
    shl ah, 6                         ; upper cylinder bits -> AH * 64
    or cl, ah                         ; CL = sector + high cylinder bits

    pop ax
    mov dl, al                        ; restore original DL from saved DX low byte
    pop ax
    ret

; disk_read: read sectors from disk using BIOS INT 13h
; Inputs:
;   AX = LBA address
;   CL = number of sectors
;   DL = drive number
;   ES:BX = destination buffer
; Returns with carry clear on success, carry set on failure.
; Preserves: AX, BX, CX, DX, DI
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax

    mov ah, 0x02
    mov di, 3                       ; retry count

.disk_retry:
    pusha
    stc                             ; force carry flag before INT 13h
    int 0x13
    popa
    jnc .disk_success

    call disk_reset
    dec di
    jnz .disk_retry
    jmp floppy_error

.disk_success:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; disk_reset: reset disk controller
; Input: DL = drive number
; Uses BIOS INT 13h function AH=0.
disk_reset:
    pusha
    mov ah, 0 
    stc
    int 0x13
    popa
    jc floppy_error
    ret

; ----------------------------------------------------------------------------
; Boot sector padding and signature
; ----------------------------------------------------------------------------
times 510-($-$$) db 0
    dw 0AA55h
