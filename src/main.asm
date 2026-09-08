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
    ; Startup confirmation
    ;
    ; Clear the screen, show the prompt and wait for Enter (start) or
    ; Esc (return to firmware). Any other key keeps waiting.
    ;
    ; clock_main jumps back here when Esc is pressed inside the program, so
    ; the user lands on this screen again and can restart or leave.
    ; -------------------------------------------------------------------------

startup:

    mov     rcx, [ConOut]
    call    [rcx + OUT_ClearScreen]

    mov     rcx, [ConOut]
    lea     rdx, [msg_confirm]
    call    [rcx + OUT_OutputString]

    mov     rax, [ConIn]
    mov     rax, [rax + IN_WaitForKey]
    mov     [WaitKey], rax

confirm_wait:

    mov     rcx, 1
    lea     rdx, [WaitKey]
    lea     r8,  [WaitIndex]
    mov     rax, [BootServices]
    call    [rax + BS_WaitForEvent]

    mov     rcx, [ConIn]
    lea     rdx, [KeyBuf]
    call    [rcx + IN_ReadKeyStroke]

    test    rax, rax
    jnz     confirm_wait

    cmp     word [KeyBuf + KEY_ScanCode], SCAN_ESC
    je      goodbye

    cmp     word [KeyBuf + KEY_UnicodeChar], CHAR_CARRIAGE_RETURN
    jne     confirm_wait

    mov     rcx, [ConOut]
    call    [rcx + OUT_ClearScreen]


    ; -------------------------------------------------------------------------
    ; Call clock.asm
    ;
    ; clock_main(EFI_SYSTEM_TABLE *SystemTable)
    ;
    ; RCX = SystemTable
    ; -------------------------------------------------------------------------

    mov     rcx, [SystemTable]

    call    clock_main

    ; EFI_SUCCESS means the user pressed Esc: back to the startup screen.
    ; Anything else is a firmware error; fall through, wait for a key and
    ; return to the firmware.

    test    rax, rax
    jz      startup


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

goodbye:

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
; Messages
; CHAR16 / UTF-16LE
; -------------------------------------------------------------------------

msg_confirm:
    db __?utf16le?__ `Clock / Stopwatch with Alarm\r\n\r\nPress Enter to start or Esc to return to the firmware.\r\nInside the program, Esc comes back to this screen.\r\n`, 0, 0

msg_bye:
    db __?utf16le?__ `\r\nReturning to firmware.\r\n`, 0, 0


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