# =================================================
# Configuration: UEFI x86_64 application
# =================================================

ASM      := nasm
LD       := lld-link
ASMFLAGS := -f win64

# PE32+ EFI application: firmware jumps to efi_main; no C runtime.
LDFLAGS  := /subsystem:efi_application /entry:efi_main /nodefaultlib

# OVMF firmware for QEMU. Override on the command line if your path differs:
#   make run OVMF=/usr/share/OVMF/OVMF_CODE_4M.fd
OVMF     ?= /usr/share/ovmf/OVMF.fd

SRC_DIR  := src
BUILD    := build

OBJ      := $(BUILD)/main.obj
EFI      := $(BUILD)/BOOTX64.EFI
IMG      := $(BUILD)/esp.img

SOURCES  := $(SRC_DIR)/main.asm
INCLUDES := $(SRC_DIR)/uefi.inc


# =================================================
# Targets
# =================================================

.PHONY: all help build image run clean

all: help

help: ## Show available targets
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_%./-]+:.*?## ' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: $(EFI) ## Assemble and link the UEFI application (build/BOOTX64.EFI)

image: $(IMG) ## Build a FAT32 EFI System Partition image with the app at /EFI/BOOT

run: $(IMG) ## Build image and boot it in QEMU with OVMF
	qemu-system-x86_64 -bios $(OVMF) -drive format=raw,file=$(IMG)

clean: ## Remove generated files
	@rm -rf $(BUILD)


# =================================================
# Build rules
# =================================================

$(OBJ): $(SOURCES) $(INCLUDES)
	@mkdir -p $(BUILD)
	$(ASM) $(ASMFLAGS) -I$(SRC_DIR)/ $(SOURCES) -o $@

$(EFI): $(OBJ)
	$(LD) $(LDFLAGS) $< /out:$@

# FAT32 EFI System Partition built with mtools (no root or loop mount needed).
# mkfs.vfat usually lives in /usr/sbin, which may be absent from a non-login PATH.
$(IMG): $(EFI)
	dd if=/dev/zero of=$@ bs=1M count=64
	PATH="$$PATH:/usr/sbin:/sbin" mkfs.vfat $@
	mmd   -i $@ ::/EFI ::/EFI/BOOT
	mcopy -i $@ $(EFI) ::/EFI/BOOT/BOOTX64.EFI
