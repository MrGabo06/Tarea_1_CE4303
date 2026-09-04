; =============================================================================
; main.asm - UEFI application entry point
;
; Assembled with:
;     nasm -f win64 main.asm -o main.obj
;
; Linked with:
;     lld-link /subsystem:efi_application /entry:efi_main
;
; Calling convention:
;     Microsoft x64
;
; RCX, RDX, R8, R9 = first four arguments
; Caller reserves 32 bytes of shadow space
; Stack remains 16-byte aligned at CALL
; =============================================================================

default rel
bits 64

%include "uefi.inc"

global efi_main
extern clock_main


section .text

; =============================================================================
; EFI_STATUS efi_main(
;     EFI_HANDLE ImageHandle,          ; RCX
;     EFI_SYSTEM_TABLE *SystemTable    ; RDX
; )
; =============================================================================

efi_main:

    ; -------------------------------------------------------------------------
    ; Prologue
    ; -------------------------------------------------------------------------

    push    rbp
    mov     rbp, rsp
    sub     rsp, 32


    ; -------------------------------------------------------------------------
    ; Save the two arguments
    ; -------------------------------------------------------------------------

    mov     [ImageHandle], rcx
    mov     [SystemTable], rdx


    ; -------------------------------------------------------------------------
    ; Cache the tables we use repeatedly
    ; -------------------------------------------------------------------------

    mov     rax, [rdx + ST_ConOut]
    mov     [ConOut], rax

    mov     rax, [rdx + ST_ConIn]
    mov     [ConIn], rax

    mov     rax, [rdx + ST_BootServices]
    mov     [BootServices], rax


    ; -------------------------------------------------------------------------
    ; BootServices->SetWatchdogTimer(0, 0, 0, NULL)
    ;
    ; Disable the ~5 minute UEFI watchdog timer.
    ; -------------------------------------------------------------------------

    mov     rax, [BootServices]

    xor     rcx, rcx
    xor     rdx, rdx
    xor     r8,  r8
    xor     r9,  r9

    call    [rax + BS_SetWatchdogTimer]


    ; -------------------------------------------------------------------------
    ; Call clock.asm
    ;
    ; clock_main(EFI_SYSTEM_TABLE *SystemTable)
    ;
    ; RCX = SystemTable
    ; -------------------------------------------------------------------------

    mov     rcx, [SystemTable]

    call    clock_main


    ; -------------------------------------------------------------------------
    ; Block until a key is available
    ;
    ; BootServices->WaitForEvent(
    ;     1,
    ;     &WaitKey,
    ;     &WaitIndex
    ; )
    ; -------------------------------------------------------------------------

    mov     rax, [ConIn]
    mov     rax, [rax + IN_WaitForKey]

    mov     [WaitKey], rax

    mov     rcx, 1
    lea     rdx, [WaitKey]
    lea     r8,  [WaitIndex]

    mov     rax, [BootServices]

    call    [rax + BS_WaitForEvent]


    ; -------------------------------------------------------------------------
    ; ConIn->ReadKeyStroke(ConIn, &KeyBuf)
    ;
    ; Consume the pending key.
    ; -------------------------------------------------------------------------

    mov     rcx, [ConIn]
    lea     rdx, [KeyBuf]

    call    [rcx + IN_ReadKeyStroke]


    ; -------------------------------------------------------------------------
    ; Print goodbye message
    ;
    ; ConOut->OutputString(ConOut, msg_bye)
    ; -------------------------------------------------------------------------

    mov     rcx, [ConOut]
    lea     rdx, [msg_bye]

    call    [rcx + OUT_OutputString]


    ; -------------------------------------------------------------------------
    ; Return EFI_SUCCESS
    ; -------------------------------------------------------------------------

    xor     eax, eax

    add     rsp, 32
    pop     rbp
    ret


section .data

; -------------------------------------------------------------------------
; Goodbye message
; CHAR16 / UTF-16LE
; -------------------------------------------------------------------------

msg_bye:
    db __?utf16le?__ `\r\nKey received. Returning to firmware.\r\n`, 0, 0


section .bss

ImageHandle:
    resq 1
SystemTable:
    resq 1
ConOut:
    resq 1
ConIn:
    resq 1
BootServices:
    resq 1
WaitKey:
    resq 1
WaitIndex:
    resq 1
KeyBuf:
    resq 1