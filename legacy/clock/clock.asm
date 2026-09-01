bits 16
org 0

start:
    mov ax, cs
    mov ds, ax

    ; Set cursor position to raw 10, column 0
    mov ah, 0x02
    mov bh, 0
    mov dh, 10        ; raw 10
    mov dl, 0         ; column 0
    int 0x10

    mov si, msg

print:
    lodsb

    test al, al
    jz done

    mov ah, 0x0E
    mov bh, 0
    int 0x10

    jmp print

done:
    cli
    hlt
    jmp done

msg:
    db "Hello, Clock!", 0