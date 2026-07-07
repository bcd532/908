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
CFLAGS=-ffreestanding -m32 -fno-stack-protector -Wall -Wextra
KERNEL_DIR=$(SRC_DIR)/kernel

# every .c in the kernel dir -> a matching .o in build/
KERNEL_C=$(wildcard $(KERNEL_DIR)/*.c)
KERNEL_OBJ=$(patsubst $(KERNEL_DIR)/%.c,$(BUILD_DIR)/%.o,$(KERNEL_C))

kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.c always
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/entry.o: $(KERNEL_DIR)/entry.asm always
	$(ASM) $(KERNEL_DIR)/entry.asm -f elf32 -o $(BUILD_DIR)/entry.o

$(BUILD_DIR)/kernel.bin: $(BUILD_DIR)/entry.o $(KERNEL_OBJ)
	$(LD) -T $(KERNEL_DIR)/linker.ld $(BUILD_DIR)/entry.o $(KERNEL_OBJ) -o $(BUILD_DIR)/kernel.elf
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
