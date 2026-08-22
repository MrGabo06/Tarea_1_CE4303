# =================================================
# Configuration
# =================================================

ASM := nasm
LD  := ld

ASMFLAGS := -f elf64


# =================================================
# Targets
# =================================================

.PHONY: all help build bootloader clock image run clean

all: help

help: ## Show available targets
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_%./-]+:.*?## ' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: image ## Build complete bootable image

bootloader: bootloader/bootloader.bin ## Build bootloader

clock: clock/clock.bin ## Build clock application

image: bootloader/bootloader.bin clock/clock.bin ## Build complete bootable image
	@mkdir -p build
	dd if=/dev/zero of=build/os.img bs=512 count=2880
	dd if=bootloader/bootloader.bin of=build/os.img bs=512 seek=0 conv=notrunc
	dd if=clock/clock.bin of=build/os.img bs=512 seek=1 conv=notrunc

run: image ## Build and run image with QEMU
	qemu-system-i386 -drive format=raw,file=build/os.img,if=floppy -boot a

clean: ## Remove generated files
	@find . -type f -name "*.o" -delete
	@rm -f bootloader/bootloader.bin
	@rm -f clock/clock.bin
	@rm -f build/os.img


# =================================================
# Bootloader
# =================================================

bootloader/bootloader.bin: bootloader/bootloader.asm
	$(ASM) -f bin $< -o $@


# =================================================
# Clock application
# =================================================

clock/clock.bin: clock/clock.asm
	$(ASM) -f bin $< -o $@