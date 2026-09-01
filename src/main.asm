; =============================================================================
; main.asm - UEFI application entry point (Phase 1: "Hello UEFI")
;
; Assembled with:  nasm -f win64
; Linked with:     lld-link /subsystem:efi_application /entry:efi_main
;
; Calling convention: Microsoft x64. Arguments go in RCX, RDX, R8, R9.
; The caller reserves 32 bytes of shadow (home) space and keeps the
; stack 16-byte aligned at the point of each CALL.
; =============================================================================

default rel
bits 64

%include "uefi.inc"

global efi_main

section .text

; EFI_STATUS efi_main(EFI_HANDLE ImageHandle /* rcx */,
;                     EFI_SYSTEM_TABLE *SystemTable /* rdx */)
efi_main:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32                     ; 32-byte shadow space; keeps 16-byte alignment

    ; Save the two arguments.
    mov     [ImageHandle], rcx
    mov     [SystemTable], rdx

    ; Cache the tables we use repeatedly.
    mov     rax, [rdx + ST_ConOut]
    mov     [ConOut], rax
    mov     rax, [rdx + ST_ConIn]
    mov     [ConIn], rax
    mov     rax, [rdx + ST_BootServices]
    mov     [BootServices], rax

    ; BootServices->SetWatchdogTimer(0, 0, 0, NULL) to stop the ~5 min reboot.
    mov     rax, [BootServices]
    xor     rcx, rcx
    xor     rdx, rdx
    xor     r8, r8
    xor     r9, r9
    call    [rax + BS_SetWatchdogTimer]

    ; ConOut->OutputString(ConOut, msg_hello)
    mov     rcx, [ConOut]
    lea     rdx, [msg_hello]
    call    [rcx + OUT_OutputString]

    ; Block until a key is available: WaitForEvent(1, &WaitKey, &WaitIndex)
    mov     rax, [ConIn]
    mov     rax, [rax + IN_WaitForKey]
    mov     [WaitKey], rax
    mov     rcx, 1
    lea     rdx, [WaitKey]
    lea     r8, [WaitIndex]
    mov     rax, [BootServices]
    call    [rax + BS_WaitForEvent]

    ; ConIn->ReadKeyStroke(ConIn, &KeyBuf) to consume the pending key.
    mov     rcx, [ConIn]
    lea     rdx, [KeyBuf]
    call    [rcx + IN_ReadKeyStroke]

    ; ConOut->OutputString(ConOut, msg_bye)
    mov     rcx, [ConOut]
    lea     rdx, [msg_bye]
    call    [rcx + OUT_OutputString]

    xor     eax, eax                    ; return EFI_SUCCESS
    add     rsp, 32
    pop     rbp
    ret


section .data

; CHAR16 / UTF-16LE strings, terminated by a CHAR16 NUL (two zero bytes).
msg_hello:
    db __?utf16le?__ `Hello from UEFI x86_64!\r\nPress any key to exit...\r\n`, 0, 0
msg_bye:
    db __?utf16le?__ `\r\nKey received. Returning to firmware.\r\n`, 0, 0


section .bss

ImageHandle:    resq 1
SystemTable:    resq 1
ConOut:         resq 1
ConIn:          resq 1
BootServices:   resq 1
WaitKey:        resq 1                  ; EFI_EVENT copied from ConIn->WaitForKey
WaitIndex:      resq 1                  ; UINTN index filled by WaitForEvent
KeyBuf:         resq 1                  ; EFI_INPUT_KEY (ScanCode:2, UnicodeChar:2)
