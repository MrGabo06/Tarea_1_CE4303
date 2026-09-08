; =============================================================================
; clock.asm - UEFI x86-64
;
; Obtains the current time using UEFI Runtime Services -> GetTime()
; and displays the time in HH:MM:SS format.
;
; The clock is updated once per second using Boot Services -> Stall().
; The cursor is repositioned before each update so the same line is reused.
;
; Keys:
;     m       cycle between clock, stopwatch and alarm modes
;     space   start / pause / resume the stopwatch
;     r       reset the stopwatch
;     left    select the previous field (alarm mode)
;     right   select the next field (alarm mode)
;     up      increment the selected field (alarm mode)
;     down    decrement the selected field (alarm mode)
;     enter   set the alarm and return to the clock
;     esc     leave clock_main and go back to the startup screen (any mode)
;
; The alarm is checked in every mode. When it fires, "ALARM" blinks on the
; line below the time until a new alarm is set.
;
; NASM:
;     nasm -f win64 clock.asm -o clock.obj
;
; Calling convention:
;     Microsoft x64
;
; Every routine that calls a firmware service owns a frame (push rbp /
; sub rsp, 32) so the callee gets its 32-byte shadow space and a 16-byte
; aligned stack. Sharing the caller's shadow space corrupts the return
; address on real firmware.
;
; Entry point:
;     RCX = EFI_SYSTEM_TABLE*
;
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

; Current wall-clock time, refreshed by read_clock in every mode
ClockString:
    dw '0', '0', ':', '0', '0', ':', '0', '0', 0

; Text shown on screen: the stopwatch counter or the alarm being edited
TimeString:
    dw '0', '0', ':', '0', '0', ':', '0', '0', 0

AlarmMessage:
    dw 'A', 'L', 'A', 'R', 'M', 0

section .text

clock_main:

    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    ; Fresh state on every entry, so returning from the startup screen
    ; restarts the program instead of resuming the previous session.

    mov     [SystemTable], rcx
    mov     byte [CurrentMode], 0
    mov     byte [StopwatchRunning], 0
    mov     byte [StopwatchTicks], 0
    mov     byte [AlarmActive], 0
    mov     byte [AlarmTriggered], 0

clock_loop:

    call    read_key

    cmp     eax, 10
    je      clock_escape

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
    ; Get current RTC time into ClockString
    ; -------------------------------------------------------------------------

    call    read_clock

    test    rax, rax
    jnz     clock_return


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

    lea     rcx, [ClockString]
    call    print_string

    call    show_alarm


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

    call    read_clock
    call    check_alarm
    call    show_alarm

    call    read_key

    cmp     eax, 10
    je      clock_escape

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

    ; Prefill the editable time with the current clock

    call    read_clock

    test    rax, rax
    jnz     clock_return

    mov     rax, [ClockString + 0]
    mov     [TimeString + 0], rax

    mov     rax, [ClockString + 8]
    mov     [TimeString + 8], rax

alarm_loop:

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    xor     rdx, rdx
    xor     r8, r8

    call    [rcx + OUT_SetCursorPosition]

    lea     rcx, [TimeString]
    call    print_string

    call    read_clock
    call    check_alarm
    call    show_alarm

    call    read_key

    cmp     eax, 10
    je      clock_escape

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

    ; Copy the edited time into AlarmTime (16 bytes, two qwords)

    mov     rax, [TimeString + 0]
    mov     [AlarmTime + 0], rax

    mov     rax, [TimeString + 8]
    mov     [AlarmTime + 8], rax

    ; Arm the alarm

    mov     byte [AlarmActive], 1
    mov     byte [AlarmTriggered], 0

    ; Back to the clock

    mov     byte [CurrentMode], 0

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
;
; read_key: polls ConIn->ReadKeyStroke and maps the key to a small code:
;     0 = no key      1 = space       3 = r / R
;     4 = left        5 = right       6 = up          7 = down
;     8 = m           9 = enter       10 = esc
;
; Owns a frame: the firmware needs 32 bytes of shadow space above the return
; address and a 16-byte aligned RSP. Calling it straight from the caller's
; frame let the firmware overwrite our return address with its argument spill.
; =============================================================================
read_key:

    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConIn]

    lea     rdx, [KeyBuf]

    call    [rcx + IN_ReadKeyStroke]

    test    rax, rax
    jnz     .no_key

    mov     eax, 10
    cmp     word [KeyBuf + KEY_ScanCode], SCAN_ESC
    je      .done

    mov     eax, 6
    cmp     word [KeyBuf + KEY_ScanCode], SCAN_UP
    je      .done

    mov     eax, 7
    cmp     word [KeyBuf + KEY_ScanCode], SCAN_DOWN
    je      .done

    mov     eax, 5
    cmp     word [KeyBuf + KEY_ScanCode], SCAN_RIGHT
    je      .done

    mov     eax, 4
    cmp     word [KeyBuf + KEY_ScanCode], SCAN_LEFT
    je      .done

    mov     eax, 1
    cmp     word [KeyBuf + KEY_UnicodeChar], ' '
    je      .done

    mov     eax, 8
    cmp     word [KeyBuf + KEY_UnicodeChar], 'm'
    je      .done

    mov     eax, 3
    cmp     word [KeyBuf + KEY_UnicodeChar], 'r'
    je      .done

    cmp     word [KeyBuf + KEY_UnicodeChar], 'R'
    je      .done

    mov     eax, 9
    cmp     word [KeyBuf + KEY_UnicodeChar], CHAR_CARRIAGE_RETURN
    je      .done

.no_key:

    xor     eax, eax

.done:

    add     rsp, 32
    pop     rbp
    ret


; =============================================================================
; CLOCK READ
;
; read_clock: RuntimeServices->GetTime into Time, then formats HH:MM:SS
; into ClockString. Returns RAX = EFI_STATUS.
; =============================================================================
read_clock:

    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    mov     rcx, [SystemTable]
    mov     rax, [rcx + ST_RuntimeServices]

    lea     rcx, [Time]
    xor     rdx, rdx

    call    [rax + RT_GetTime]

    test    rax, rax
    jnz     .done

    movzx   eax, byte [Time + TIME_Hour]
    lea     rcx, [ClockString + 0]
    call    put_two_digits

    movzx   eax, byte [Time + TIME_Minute]
    lea     rcx, [ClockString + 6]
    call    put_two_digits

    movzx   eax, byte [Time + TIME_Second]
    lea     rcx, [ClockString + 12]
    call    put_two_digits

    xor     eax, eax

.done:

    add     rsp, 32
    pop     rbp
    ret


; put_two_digits: EAX = value (0..99), RCX = destination of two CHAR16
put_two_digits:

    xor     edx, edx
    mov     r8d, 10
    div     r8d

    add     eax, '0'
    mov     [rcx], ax

    add     edx, '0'
    mov     [rcx + 2], dx

    ret


; =============================================================================
; ALARM
;
; check_alarm: compares ClockString with AlarmTime and latches AlarmTriggered.
; Called from every mode, so the alarm fires regardless of what is on screen.
; =============================================================================
check_alarm:

    cmp     byte [AlarmActive], 1
    jne     .done

    cmp     byte [AlarmTriggered], 1
    je      .done

    mov     al, [ClockString + 0]
    cmp     al, [AlarmTime + 0]
    jne     .done

    mov     al, [ClockString + 2]
    cmp     al, [AlarmTime + 2]
    jne     .done

    mov     al, [ClockString + 6]
    cmp     al, [AlarmTime + 6]
    jne     .done

    mov     al, [ClockString + 8]
    cmp     al, [AlarmTime + 8]
    jne     .done

    mov     al, [ClockString + 12]
    cmp     al, [AlarmTime + 12]
    jne     .done

    mov     al, [ClockString + 14]
    cmp     al, [AlarmTime + 14]
    jne     .done

    mov     byte [AlarmTriggered], 1

.done:
    ret


; show_alarm: when triggered, prints "ALARM" on row 1 alternating white-on-red
; and red-on-black once per second (parity of the seconds digit), then restores
; the default attribute so the time keeps its normal colors.
show_alarm:

    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    cmp     byte [AlarmTriggered], 1
    jne     .done

    mov     edx, EFI_WHITE | EFI_BG_RED

    test    byte [ClockString + 14], 1
    jz      .attr

    mov     edx, EFI_RED

.attr:

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    call    [rcx + OUT_SetAttribute]

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    xor     rdx, rdx
    mov     r8, 1

    call    [rcx + OUT_SetCursorPosition]

    lea     rcx, [AlarmMessage]
    call    print_string

    mov     rcx, [SystemTable]
    mov     rcx, [rcx + ST_ConOut]

    mov     edx, EFI_LIGHTGRAY

    call    [rcx + OUT_SetAttribute]

.done:

    add     rsp, 32
    pop     rbp
    ret


; =============================================================================
; RETURN
;
; clock_escape: Esc was pressed in any mode. Return EFI_SUCCESS so main.asm
; shows the startup screen again.
;
; clock_return: leaves clock_main with RAX already holding the status
; (an EFI error from read_clock, or EFI_SUCCESS from clock_escape).
; =============================================================================

clock_escape:

    xor     eax, eax

clock_return:

    add     rsp, 32
    pop     rbp
    ret


; =============================================================================
; PRINT STRING
;
; RCX = CHAR16 string
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
