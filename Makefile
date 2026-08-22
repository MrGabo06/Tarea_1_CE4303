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
# NOTE: When adding rules, add what it does after
# target: requisites preceeded by ## so targets
# remain automatically documented
# =================================================

.PHONY: all help build clean

all: help

help: ## Show available targets
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_%./-]+:.*?## ' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: $(TARGETS) ## Build all ASM files

clean: ## Remove generated files
	@rm -f $(TARGETS)
	@find . -type f -name "*.o" -delete


# =================================================
# Generic ASM rule
# =================================================

%: %.asm
	$(ASM) $(ASMFLAGS) $< -o $@.o
	$(LD) $@.o -o $@
	@rm -f $@.o