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

AlarmField:
    db 0

AlarmTime:
    times 16 db 0

AlarmActive:
    db 0

AlarmTriggered:
    db 0

TimeString:
    dw '0', '0', ':', '0', '0', ':', '0', '0', 0

AlarmMessage:
    dw 'A','L','A','R','M','A',0

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

    cmp     eax, 8
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

    ; -------------------------------------------------------------------------
    ; Get current RTC time
    ; -------------------------------------------------------------------------

    mov     rcx, [SystemTable]
    mov     rax, [rcx + ST_RuntimeServices]

    lea     rcx, [Time]
    xor     rdx, rdx

    call    [rax + RT_GetTime]

    test    rax, rax
    jnz     clock_return


    ; -------------------------------------------------------------------------
    ; Convert hours to HH
    ; -------------------------------------------------------------------------

    movzx   eax, byte [Time + TIME_Hour]

    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 0], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 2], ax


    ; -------------------------------------------------------------------------
    ; Convert minutes to MM
    ; -------------------------------------------------------------------------

    movzx   eax, byte [Time + TIME_Minute]

    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 6], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 8], ax


    ; -------------------------------------------------------------------------
    ; Convert seconds to SS
    ; -------------------------------------------------------------------------

    movzx   eax, byte [Time + TIME_Second]

    xor     edx, edx
    mov     ecx, 10
    div     ecx

    add     eax, '0'
    mov     [TimeString + 12], ax

    mov     eax, edx
    add     eax, '0'
    mov     [TimeString + 14], ax


    ; -------------------------------------------------------------------------
    ; Check alarm
    ; -------------------------------------------------------------------------

    call    check_alarm


    ; -------------------------------------------------------------------------
    ; Display current time
    ; -------------------------------------------------------------------------

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    xor     rdx, rdx
    xor     r8, r8

    call    [rcx + OUT_SetCursorPosition]

    lea     rcx, [TimeString]
    call    print_string


    ; -------------------------------------------------------------------------
    ; Display ALARMA if triggered
    ; -------------------------------------------------------------------------

    cmp     byte [AlarmTriggered], 1
    jne     .no_alarm

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    xor     rdx, rdx
    mov     r8, 1

    call    [rcx + OUT_SetCursorPosition]

    lea     rcx, [AlarmMessage]
    call    print_string

.no_alarm:


    ; -------------------------------------------------------------------------
    ; Wait 1 second
    ; -------------------------------------------------------------------------

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

    cmp     eax, 8
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

    mov     byte [AlarmField], 0

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

    cmp     eax, 4
    je      alarm_left

    cmp     eax, 5
    je      alarm_right

    cmp     eax, 6
    je      alarm_up

    cmp     eax, 7
    je      alarm_down

    cmp     eax, 8
    je      alarm_exit

    cmp     eax, 9
    je      alarm_set

    jmp     alarm_loop

alarm_set:

    ; Copiar hora configurada a AlarmTime
    mov     rsi, TimeString
    mov     rdi, AlarmTime
    mov     rcx, 16

    rep     movsb

    ; Activar alarma
    mov     byte [AlarmActive], 1
    mov     byte [AlarmTriggered], 0

    ; Volver al reloj
    jmp     clock_loop

alarm_left:

    cmp     byte [AlarmField], 0
    je      alarm_loop

    dec     byte [AlarmField]
    jmp     alarm_loop


alarm_right:

    cmp     byte [AlarmField], 2
    je      alarm_loop

    inc     byte [AlarmField]
    jmp     alarm_loop

alarm_up:

    cmp     byte [AlarmField], 0
    je      alarm_up_hours

    cmp     byte [AlarmField], 1
    je      alarm_up_minutes

    jmp     alarm_up_seconds


alarm_up_hours:

    inc     byte [TimeString + 2]

    cmp     byte [TimeString + 2], '9' + 1
    jne     alarm_loop

    mov     byte [TimeString + 2], '0'

    inc     byte [TimeString + 0]

    cmp     byte [TimeString + 0], '2' + 1
    jne     alarm_loop

    mov     byte [TimeString + 0], '0'

    jmp     alarm_loop


alarm_up_minutes:

    inc     byte [TimeString + 8]

    cmp     byte [TimeString + 8], '9' + 1
    jne     alarm_loop

    mov     byte [TimeString + 8], '0'

    inc     byte [TimeString + 6]

    cmp     byte [TimeString + 6], '6'
    jne     alarm_loop

    mov     byte [TimeString + 6], '0'

    jmp     alarm_loop


alarm_up_seconds:

    inc     byte [TimeString + 14]

    cmp     byte [TimeString + 14], '9' + 1
    jne     alarm_loop

    mov     byte [TimeString + 14], '0'

    inc     byte [TimeString + 12]

    cmp     byte [TimeString + 12], '6'
    jne     alarm_loop

    mov     byte [TimeString + 12], '0'

    jmp     alarm_loop


alarm_down:

    cmp     byte [AlarmField], 0
    je      alarm_down_hours

    cmp     byte [AlarmField], 1
    je      alarm_down_minutes

    jmp     alarm_down_seconds


alarm_down_hours:

    cmp     byte [TimeString + 0], '0'
    jne     alarm_down_hours_normal

    cmp     byte [TimeString + 2], '0'
    jne     alarm_down_hours_borrow

    mov     byte [TimeString + 0], '2'
    mov     byte [TimeString + 2], '3'
    jmp     alarm_loop


alarm_down_hours_borrow:

    dec     byte [TimeString + 0]
    mov     byte [TimeString + 2], '9'
    jmp     alarm_loop


alarm_down_hours_normal:

    cmp     byte [TimeString + 2], '0'
    jne     alarm_down_hours_normal_dec

    dec     byte [TimeString + 0]
    mov     byte [TimeString + 2], '9'
    jmp     alarm_loop


alarm_down_hours_normal_dec:

    dec     byte [TimeString + 2]
    jmp     alarm_loop


alarm_down_minutes:

    cmp     byte [TimeString + 6], '0'
    jne     alarm_down_minutes_normal

    mov     byte [TimeString + 6], '5'
    mov     byte [TimeString + 8], '9'
    jmp     alarm_loop


alarm_down_minutes_normal:

    cmp     byte [TimeString + 8], '0'
    jne     alarm_down_minutes_normal_dec

    dec     byte [TimeString + 6]
    mov     byte [TimeString + 8], '9'
    jmp     alarm_loop


alarm_down_minutes_normal_dec:

    dec     byte [TimeString + 8]
    jmp     alarm_loop


alarm_down_seconds:

    cmp     byte [TimeString + 12], '0'
    jne     alarm_down_seconds_normal

    mov     byte [TimeString + 12], '5'
    mov     byte [TimeString + 14], '9'
    jmp     alarm_loop


alarm_down_seconds_normal:

    cmp     byte [TimeString + 14], '0'
    jne     alarm_down_seconds_normal_dec

    dec     byte [TimeString + 12]
    mov     byte [TimeString + 14], '9'
    jmp     alarm_loop


alarm_down_seconds_normal_dec:

    dec     byte [TimeString + 14]
    jmp     alarm_loop

alarm_exit:

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

    cmp     word [KeyBuf], 1
    je      key_up

    cmp     word [KeyBuf], 2
    je      key_down

    cmp     word [KeyBuf], 3
    je      key_right

    cmp     word [KeyBuf], 4
    je      key_left

    cmp     word [KeyBuf + 2], ' '
    je      key_space

    cmp     word [KeyBuf + 2], 'm'
    je      key_m

    cmp     word [KeyBuf + 2], 'r'
    je      key_r

    cmp     word [KeyBuf + 2], 'R'
    je      key_r

    cmp     word [KeyBuf + 2], 13
    je      key_enter

no_key:

    xor     eax, eax
    ret


key_up:

    mov     eax, 6
    ret


key_down:

    mov     eax, 7
    ret


key_right:

    mov     eax, 5
    ret


key_left:

    mov     eax, 4
    ret


key_space:

    mov     eax, 1
    ret


key_m:

    mov     eax, 8
    ret


key_r:

    mov     eax, 3
    ret

key_enter:
    mov     eax, 9
    ret

check_alarm:

    cmp     byte [AlarmActive], 1
    jne     .done

    cmp     byte [AlarmTriggered], 1
    je      .done

    mov     al, [TimeString + 0]
    cmp     al, [AlarmTime + 0]
    jne     .done

    mov     al, [TimeString + 2]
    cmp     al, [AlarmTime + 2]
    jne     .done

    mov     al, [TimeString + 6]
    cmp     al, [AlarmTime + 6]
    jne     .done

    mov     al, [TimeString + 8]
    cmp     al, [AlarmTime + 8]
    jne     .done

    mov     al, [TimeString + 12]
    cmp     al, [AlarmTime + 12]
    jne     .done

    mov     al, [TimeString + 14]
    cmp     al, [AlarmTime + 14]
    jne     .done

    mov     byte [AlarmTriggered], 1

.done:
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