; ============================================================================
; Bootloader for a FAT12 floppy image
; ============================================================================
;
; This file is a 512-byte boot sector. It contains the FAT12 BIOS Parameter
; Block (BPB) and Extended Boot Record (EBR), followed by the bootloader code.
; The BIOS loads this sector at 0x7C00 and begins execution at the first byte.
;
org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; ----------------------------------------------------------------------------
; FAT12 BIOS Parameter Block (BPB)
; ----------------------------------------------------------------------------
; This section is metadata, not code. The CPU does not execute it directly.
; The first instruction at the top jumps over this data and into the boot code.
; ----------------------------------------------------------------------------

jmp short start    ; skip the BPB and go to the boot code
nop

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
ebr_volume_label:               db 'NINE ZERO 8'    ; volume label (15 chars)
ebr_system_id:                  db 'FAT12   '           ; filesystem type (8 chars)

; ----------------------------------------------------------------------------
; Bootloader code
; ----------------------------------------------------------------------------
start:
    jmp main

; ---------------------------------------------------------------------------
; puts: print a null-terminated string using BIOS teletype output
; Inputs:
;   DS:SI = pointer to the string
; Preserves: AX, SI
; ---------------------------------------------------------------------------
puts:
    push si
    push ax

.puts_loop:
    lodsb                   ; load byte at DS:SI into AL, increment SI
    or al, al               ; set zero flag if AL == 0
    jz .puts_done

    mov ah, 0x0E            ; BIOS teletype function
    mov bh, 0               ; display page 0
    int 0x10
    jmp .puts_loop

.puts_done:
    pop ax
    pop si
    ret

; ---------------------------------------------------------------------------
; main: bootloader entry point
; ---------------------------------------------------------------------------
main:
    ; Initialize segment registers for simple memory access.
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; Initialize stack.
    mov ss, ax
    mov sp, 0x7C00

    ; Store the BIOS drive number into the boot sector metadata.
    ; This proves the drive number is available in DL.
    mov [ebr_drive_number], dl

    ; Read one sector from the disk into memory at 0x7E00.
    mov ax, 1               ; LBA sector 1 (second sector)
    mov cl, 1               ; read 1 sector
    mov bx, 0x7E00          ; destination: 0x7E00
    call disk_read

    ; Print a message once the disk read completes.
    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

floppy_error:
    mov si, msg_read_failed
    call puts
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

    call lba_to_chs

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
; Data strings
; ----------------------------------------------------------------------------
msg_hello: db '908 booting...', ENDL, 0
msg_read_failed: db 'Read from disk failed!', ENDL, 0

; ----------------------------------------------------------------------------
; Boot sector padding and signature
; ----------------------------------------------------------------------------
times 510-($-$$) db 0
    dw 0AA55h
