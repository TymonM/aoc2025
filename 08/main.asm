; NASM syntax (Intel) for macOS x86_64
default rel

extern _write_int
extern _quickselect

section .text
global _start

_start:
    lea rdi, [arr]
    lea rsi, [dummy]
    mov rdx, 8
    mov rcx, 3          ; 4 should be in the 4th position
    call _quickselect

    mov rcx, 8
    lea rsi, [arr]
.print_loop:
    mov rdi, [rsi]
    push rcx
    push rsi
    call _write_int
    pop rsi
    pop rcx
    add rsi, 8
    dec rcx
    jnz .print_loop

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

section .data
arr: dq 7, 2, 1, 6, 8, 5, 3, 4
dummy: dq 0, 0, 0, 0, 0, 0, 0, 0