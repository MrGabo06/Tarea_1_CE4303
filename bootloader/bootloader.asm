org 0x7C00

        jmp short Start

Msg:
        db "Hello World! "

EndMsg:

BootDrive:
        db 0


Start:
        ; Initialize segments and stack
        cli

        xor ax, ax
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov sp, 0x7C00

        sti

        ; Save boot drive number
        mov [BootDrive], dl

        ; Print "Hello World!"
        mov bx, 0x000F
        mov cx, 1
        xor dx, dx
        cld

Print:
        mov si, Msg

Char:
        ; Set cursor position
        mov ah, 0x02
        int 0x10

        ; Load next character
        lodsb

        ; Print character
        mov ah, 0x09
        int 0x10

        ; Move cursor
        inc dl

        cmp dl, 80
        jne Skip

        xor dl, dl
        inc dh

        cmp dh, 25
        jne Skip

        xor dh, dh

Skip:
        cmp si, EndMsg
        jne Char


LoadClock:
        ; Load clock.bin at physical address 0x10000
        mov ax, 0x1000
        mov es, ax
        xor bx, bx

        ; Read one sector from disk
        mov ah, 0x02
        mov al, 1

        mov ch, 0
        mov cl, 2
        mov dh, 0
        mov dl, [BootDrive]

        int 0x13

        ; Jump to error handler if disk read failed
        jc DiskError

        ; Jump to clock.bin
        jmp 0x1000:0x0000


DiskError:
        ; Print error character
        mov ah, 0x0E
        mov al, 'E'
        mov bh, 0
        int 0x10


Hang:
        cli
        hlt
        jmp Hang


        ; Fill boot sector up to 510 bytes
times 0x200 - 2 - ($ - $$) db 0

        ; Boot sector signature
        dw 0xAA55