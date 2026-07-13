# 908

## WHAT IS IT
908 is an operating system for me to learn more about computers and C. there are really no goals in mind except for it being an environment where everything is my problem.

## v0.1.0-alpha

### WHAT DOES IT HAVE
- Two-stage boot: bootloader -> kernel on a FAT12 floppy
- Real mode -> 32-bit protected mdoe
- Freestanding C kernel (i686-elf toolchain)
- VGA text console: scrolling, color, cursor
- IDT + CPU execution handling
- PIC remap + keyboard driver (scancodes, shift, backspace)
- Interactive shell: line editing, commands (help, clear)

### RUN
`qemu-system-i386 -fda main_floppy.img`

<sub>908 bc 908</sub>
