bits 64
default rel

section .text
global _start

_start:
    mov eax, 1
    mov edi, 1
    lea rsi, [msg]
    mov edx, msg_len
    syscall

    mov eax, 60
    xor edi, edi
    syscall

section .rodata
msg: db "hello from static demo elf", 10
msg_len equ $ - msg
