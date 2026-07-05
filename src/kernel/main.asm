bits 16
org 0x0000

%define ENDL 0x0D, 0X0A

start:
    cli
    mov ax, 0x07E0
    mov ds, ax

    mov si, k_msg
    call puts

     

puts:
    push si 
    push ax

.puts_loop
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
  

k_msg: db 'Hey', ENDL, 0

.halt:
    hlt
    jmp .halt
