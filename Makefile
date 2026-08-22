# =================================================
# Configuration
# =================================================

ASM := nasm
LD  := ld

ASMFLAGS := -f elf64

SOURCES := $(shell find . -type f -name "*.asm")
TARGETS := $(SOURCES:.asm=)


# =================================================
# Targets
# =================================================

.PHONY: all help build clean bootloader

all: help

help: ## Show available targets
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_%./-]+:.*?## ' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: $(TARGETS) ## Build all ELF64 ASM files

bootloader: bootloader/bootloader.bin ## Build bootloader

clean: ## Remove generated files
	@find . -type f -name "*.o" -delete
	@rm -f bootloader/bootloader.bin


# =================================================
# Bootloader rule
# =================================================

bootloader/bootloader.bin: bootloader/bootloader.asm
	$(ASM) -f bin $< -o $@


# =================================================
# Generic ELF64 ASM rule
# =================================================

%: %.asm
	$(ASM) $(ASMFLAGS) $< -o $@.o
	$(LD) $@.o -o $@
	@rm -f $@.o