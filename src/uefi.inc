; =============================================================================
; uefi.inc - UEFI structure offsets and constants
; Values come from the UEFI Specification. Every table begins
; with a 24-byte EFI_TABLE_HEADER, so member offsets are counted
; from there. All pointers are 8 bytes (x86_64).
; =============================================================================

; --- EFI_SYSTEM_TABLE ---
%define ST_ConIn                48
%define ST_ConOut               64
%define ST_RuntimeServices      88
%define ST_BootServices         96

; --- EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL ---
%define OUT_Reset               0
%define OUT_OutputString        8
%define OUT_TestString          16
%define OUT_QueryMode           24
%define OUT_SetMode             32
%define OUT_SetAttribute        40
%define OUT_ClearScreen         48
%define OUT_SetCursorPosition   56
%define OUT_EnableCursor        64

; --- EFI_SIMPLE_TEXT_INPUT_PROTOCOL ---
%define IN_Reset                0
%define IN_ReadKeyStroke        8
%define IN_WaitForKey           16

; --- EFI_RUNTIME_SERVICES ---
%define RT_GetTime              24
%define RT_SetTime              32

; --- EFI_BOOT_SERVICES ---
%define BS_CreateEvent          80
%define BS_SetTimer             88
%define BS_WaitForEvent         96
%define BS_SignalEvent          104
%define BS_CloseEvent           112
%define BS_Stall                248
%define BS_SetWatchdogTimer     256

; --- EFI_INPUT_KEY (4 bytes) ---
%define KEY_ScanCode            0       ; UINT16
%define KEY_UnicodeChar         2       ; CHAR16

; --- EFI_TIME (partial) ---
%define TIME_Year               0       ; UINT16
%define TIME_Month              2       ; UINT8
%define TIME_Day                3       ; UINT8
%define TIME_Hour               4       ; UINT8
%define TIME_Minute             5       ; UINT8
%define TIME_Second             6       ; UINT8

; --- Text attributes: foreground | (background << 4) ---
%define EFI_BLACK               0x00
%define EFI_BLUE                0x01
%define EFI_GREEN               0x02
%define EFI_RED                 0x04
%define EFI_LIGHTGRAY           0x07
%define EFI_YELLOW              0x0E
%define EFI_WHITE               0x0F
%define EFI_BG_RED              0x40
%define EFI_BG_BLUE             0x10

; --- Common EFI_STATUS values (high bit set = error) ---
%define EFI_SUCCESS             0
%define EFI_NOT_READY           0x8000000000000006
