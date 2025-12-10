; NASM syntax (Intel) for macOS x86_64
default rel

extern _read_int
extern _write_int

section .text
global _start

_start:
    call _init
    call _first

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

; read in points from input to `points`
_init:
    ; rdi is input cursor, rsi is points cursor
    lea rdi, [input]
    lea rsi, [points]
    mov rcx, input_lines*2 ; num values to read
.read_point_value:
    push rcx
    call _read_int
    mov [rsi], rax
    inc rdi ; skip comma or newline
    add rsi, 8

    pop rcx
    dec rcx
    jnz .read_point_value

    ret

_first:
    mov qword [output], 0
    ; rdi is current first point pointer
    ; rsi is sentinel
    ; rcx is second point pointer
    lea rdi, points
    lea rsi, points
    add rsi, input_lines*16
.rdi_loop:
    cmp rdi, rsi
    jge .done
    mov rcx, rdi
    add rcx, 16 ; start from next point
.rcx_loop:
    cmp rcx, rsi
    jge .step_rdi_loop

    ; get width, using branchless absolute value
    ; x = (x xor (x >> 63)) - (x >> 63)
    mov rax, [rdi]
    sub rax, [rcx]
    mov r8, rax
    shr r8, 63
    xor rax, r8
    sub rax, r8
    inc rax ; width + 1

    ; get height, similarly
    mov rdx, [rdi+8]
    sub rdx, [rcx+8]
    mov r8, rdx
    shr r8, 63
    xor rdx, r8
    sub rdx, r8
    inc rdx ; height + 1

    imul rax, rdx ; area
    cmp rax, [output]
    jl .step_rcx_loop
    mov qword [output], rax
.step_rcx_loop:
    add rcx, 16 ; 2 qwords per points
    jmp .rcx_loop

.step_rdi_loop:
    add rdi, 16
    jmp .rdi_loop

.done:
    mov rdi, [output]
    call _write_int
    ret

section .data
%include "09/input.inc"

section .bss
output: resb 8
points: resq input_lines*2 ; 2 qwords per point