ASM=nasm

SRC_DIR=src
BUILD_DIR=build

.PHONY: all floppy_image kernel bootloader clean always

#
# Floppy img
#
floppy_image: $(BUILD_DIR)/main_floppy.img
$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"


#
# Bootloader
#
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin


#
# Kernel (32-bit: asm entry stub + freestanding C, linked to a flat image)
#
CC=i686-elf-gcc
LD=i686-elf-ld
OBJCOPY=i686-elf-objcopy
# -fno-tree-loop-distribute-patterns: stop GCC turning our mem*() loops into
# calls to memcpy/memset (i.e. into themselves -> infinite recursion).
# -mgeneral-regs-only: forbid FPU/SSE in kernel code. Required for
# __attribute__((interrupt)) handlers (an ISR must not touch FP registers).
KERNEL_DIR=$(SRC_DIR)/kernel
# -I$(KERNEL_DIR) makes the angle-bracket includes (<lib/mem.h>, <cpu/idt.h>, ...) resolve
CFLAGS=-ffreestanding -m32 -fno-stack-protector -fno-tree-loop-distribute-patterns -mgeneral-regs-only -Wall -Wextra -I$(KERNEL_DIR)
LINKER_LD=$(KERNEL_DIR)/cpu/linker.ld

# Sources live in subdirs (cpu/ drivers/ lib/ core/); objects stay flat in build/.
# VPATH lets the pattern rule find a .c by basename in any of those dirs.
KERNEL_SUBDIRS=$(KERNEL_DIR)/cpu $(KERNEL_DIR)/drivers $(KERNEL_DIR)/lib $(KERNEL_DIR)/core
vpath %.c $(KERNEL_SUBDIRS)
KERNEL_C=$(notdir $(wildcard $(addsuffix /*.c,$(KERNEL_SUBDIRS))))
KERNEL_OBJ=$(patsubst %.c,$(BUILD_DIR)/%.o,$(KERNEL_C))

kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/%.o: %.c always
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/entry.o: $(KERNEL_DIR)/cpu/entry.asm always
	$(ASM) $< -f elf32 -o $@

# ISR stubs + isr_stub_table (32-bit; NASM defaults BITS 32 for -f elf32)
$(BUILD_DIR)/macros.o: $(KERNEL_DIR)/cpu/macros.asm always
	$(ASM) $< -f elf32 -o $@

$(BUILD_DIR)/kernel.bin: $(BUILD_DIR)/entry.o $(BUILD_DIR)/macros.o $(KERNEL_OBJ)
	$(LD) -T $(LINKER_LD) $(BUILD_DIR)/entry.o $(BUILD_DIR)/macros.o $(KERNEL_OBJ) -o $(BUILD_DIR)/kernel.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/kernel.elf $(BUILD_DIR)/kernel.bin

#
# Always
#
always:
	mkdir -p $(BUILD_DIR)

#
# Clean
#
clean:
	rm -rf $(BUILD_DIR)/*
