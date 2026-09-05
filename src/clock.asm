; =============================================================================
;*
; clock.asm - UEFI x86-64
;*
; Obtains the current time using UEFI Runtime Services -> GetTime()
; and displays the time in HH:MM:SS format.
;*
; The clock is updated once per second using Boot Services -> Stall().
; The cursor is repositioned before each update so the same line is reused.
;*
; Pressing the DOWN arrow cycles between clock, stopwatch and alarm modes.
;*
; NASM:
;     nasm -f win64 clock.asm -o clock.obj
;*
; Calling convention:
;     Microsoft x64
;*
; Entry point:
;     RCX = EFI_SYSTEM_TABLE*
;*
; Return:
;     RAX = EFI_STATUS
; =============================================================================

default rel
bits 64

%include "uefi.inc"

global clock_main

section .data

SystemTable:
    dq 0

Time:
    times 16 db 0

KeyBuf:
    times 4 db 0

CurrentMode:
    db 0

StopwatchRunning:
    db 0

StopwatchTicks:
    db 0

TimeString:
    dw '0', '0', ':', '0', '0', ':', '0', '0', 0

section .text

clock_main:

    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    mov     [SystemTable], rcx
    mov     byte [CurrentMode], 0
    mov     byte [StopwatchRunning], 0
    mov     byte [StopwatchTicks], 0

clock_loop:

    call    read_key

    cmp     eax, 2
    je      enter_stopwatch

    jmp     clock_continue

enter_stopwatch:

    mov     byte [CurrentMode], 1
    mov     byte [StopwatchRunning], 0
    mov     byte [StopwatchTicks], 0

    mov     word [TimeString + 0], '0'
    mov     word [TimeString + 2], '0'
    mov     word [TimeString + 4], ':'
    mov     word [TimeString + 6], '0'
    mov     word [TimeString + 8], '0'
    mov     word [TimeString + 10], ':'
    mov     word [TimeString + 12], '0'
    mov     word [TimeString + 14], '0'

    jmp     stopwatch_loop

clock_continue:

    mov     rcx, [SystemTable]
    mov     rax, [rcx + ST_RuntimeServices]

    lea     rcx, [Time]
    xor     rdx, rdx

    call    [rax + RT_GetTime]

    test    rax, rax
    jnz     clock_return

    movzx   eax, byte [Time + TIME_Hour]
    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 0], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 2], ax

    movzx   eax, byte [Time + TIME_Minute]
    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 6], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 8], ax

    movzx   eax, byte [Time + TIME_Second]
    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 12], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 14], ax

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    xor     rdx, rdx
    xor     r8, r8

    call    [rcx + OUT_SetCursorPosition]

    lea     rcx, [TimeString]
    call    print_string

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_BootServices]

    mov     rax, [rcx + BS_Stall]
    mov     rcx, 1000000

    call    rax

    jmp     clock_loop


; =============================================================================
; STOPWATCH MODE
; =============================================================================

stopwatch_loop:

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    xor     rdx, rdx
    xor     r8, r8

    call    [rcx + OUT_SetCursorPosition]

    lea     rcx, [TimeString]
    call    print_string

    call    read_key

    cmp     eax, 1
    je      stopwatch_space

    cmp     eax, 2
    je      stopwatch_down

    cmp     eax, 3
    je      stopwatch_reset

    jmp     stopwatch_wait


stopwatch_space:

    xor     byte [StopwatchRunning], 1
    jmp     stopwatch_wait


stopwatch_down:

    mov     byte [CurrentMode], 2
    mov     byte [StopwatchRunning], 0
    mov     byte [StopwatchTicks], 0

    jmp     enter_alarm

stopwatch_reset:

    mov     byte [StopwatchRunning], 0
    mov     byte [StopwatchTicks], 0

    mov     word [TimeString + 0], '0'
    mov     word [TimeString + 2], '0'
    mov     word [TimeString + 4], ':'
    mov     word [TimeString + 6], '0'
    mov     word [TimeString + 8], '0'
    mov     word [TimeString + 10], ':'
    mov     word [TimeString + 12], '0'
    mov     word [TimeString + 14], '0'

    jmp     stopwatch_wait


stopwatch_wait:

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_BootServices]

    mov     rax, [rcx + BS_Stall]
    mov     rcx, 100000

    call    rax

    cmp     byte [StopwatchRunning], 1
    jne     stopwatch_loop

    inc     byte [StopwatchTicks]

    cmp     byte [StopwatchTicks], 10
    jne     stopwatch_loop

    mov     byte [StopwatchTicks], 0

    inc     byte [TimeString + 14]

    cmp     byte [TimeString + 14], '9' + 1
    jne     stopwatch_loop

    mov     byte [TimeString + 14], '0'
    inc     byte [TimeString + 12]

    cmp     byte [TimeString + 12], '6'
    jne     stopwatch_loop

    mov     byte [TimeString + 12], '0'
    inc     byte [TimeString + 8]

    cmp     byte [TimeString + 8], '9' + 1
    jne     stopwatch_loop

    mov     byte [TimeString + 8], '0'
    inc     byte [TimeString + 6]

    cmp     byte [TimeString + 6], '6'
    jne     stopwatch_loop

    mov     byte [TimeString + 6], '0'
    inc     byte [TimeString + 2]

    cmp     byte [TimeString + 2], '9' + 1
    jne     stopwatch_loop

    mov     byte [TimeString + 2], '0'
    inc     byte [TimeString + 0]

    jmp     stopwatch_loop


; =============================================================================
; ALARM MODE
; =============================================================================

enter_alarm:

    mov     rcx, [SystemTable]
    mov     rax, [rcx + ST_RuntimeServices]

    lea     rcx, [Time]
    xor     rdx, rdx

    call    [rax + RT_GetTime]

    test    rax, rax
    jnz     clock_return

    movzx   eax, byte [Time + TIME_Hour]
    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 0], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 2], ax

    movzx   eax, byte [Time + TIME_Minute]
    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 6], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 8], ax

    movzx   eax, byte [Time + TIME_Second]
    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 12], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 14], ax

    jmp     alarm_loop

alarm_loop:

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    xor     rdx, rdx
    xor     r8, r8

    call    [rcx + OUT_SetCursorPosition]

    lea     rcx, [TimeString]
    call    print_string

    call    read_key

    cmp     eax, 2
    je      alarm_down

    jmp     alarm_loop



alarm_down:

    mov     byte [CurrentMode], 0
    mov     byte [StopwatchRunning], 0
    mov     byte [StopwatchTicks], 0

    jmp     clock_loop


; =============================================================================
; KEYBOARD
; =============================================================================

read_key:

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConIn]

    lea     rdx, [KeyBuf]

    call    [rcx + IN_ReadKeyStroke]

    test    rax, rax
    jnz     no_key

    cmp     word [KeyBuf + 2], ' '
    je      key_space

    cmp     word [KeyBuf + 2], 'm'
    je      key_m

    cmp     word [KeyBuf + 2], 'r'
    je      key_r

    cmp     word [KeyBuf + 2], 'R'
    je      key_r


no_key:

    xor     eax, eax
    ret


key_space:

    mov     eax, 1
    ret


key_m:

    mov     eax, 2
    ret


key_r:

    mov     eax, 3
    ret


; =============================================================================
; RETURN
; =============================================================================

clock_return:

    add     rsp, 32
    pop     rbp
    ret


; =============================================================================
; PRINT STRING
; =============================================================================

print_string:

    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    mov     rdx, rcx

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    call    [rcx + OUT_OutputString]

    add     rsp, 32
    pop     rbp
    ret