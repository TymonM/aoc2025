; NASM syntax (Intel) for macOS x86_64
default rel

extern _write_int

section .text
global _start

_start:
    call _first

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

_first:
    mov qword [output], 0 ; accumulator for answer
    mov rcx, input_lines
    lea rdi, [input] ; cursor
    mov r8, 0 ; max left
    mov r9, 0 ; max right

.process_line:
    cmp byte [rdi], 10 ; check if line finished
    je .end_line
    movzx rax, byte [rdi]
    sub rax, '0'

    ; update right if better
    cmp rax, r9
    jle .test_left
    mov r9, rax
.test_left:
    cmp byte [rdi+1], 10
    je .end_line
    cmp rax, r8
    jle .keep_processing_line
    mov r8, rax
    xor r9, r9
.keep_processing_line:
    inc rdi
    jmp .process_line

.end_line:
    ; update output
    mul r8, 10
    add [output], r8
    add [output], r9
    xor r8, r8
    xor r9, r9

    add rdi, 2 ; skip last char and newline
    dec rcx
    jnz .process_line

.done:
    mov rdi, [output]
    call _write_int
    ret


section .data
%include "03/input.inc"

section .bss
output: resb 8