; NASM syntax (Intel) for macOS x86_64
default rel

extern _write_int
extern _read_int

section .text
global _start

_start:
    call _first

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

_first:
    mov qword [output], 0 ; counter of zeros
    mov r12, 50 ; current dial position
    mov rcx, input_lines
    lea rdi, [input]

.process_line:
    test rcx, rcx
    jz .done
    dec rcx
    
    cmp byte [rdi], 'L'
    je .left

.right:
    inc rdi
    push rcx
    call _read_int
    pop rcx

    add r12, rax ; rotate the dial
    jmp .check_dial
.left:
    inc rdi
    push rcx
    call _read_int
    pop rcx

    sub r12, rax ; rotate the dial
    add r12, 1000000 ; prevent negative values
.check_dial:
    inc rdi ; skip newline char

    ; r12 := r12 mod 100
    mov rax, r12
    mov rdx, 0
    mov r8, 100
    div r8
    mov r12, rdx

    ; if r12 == 0, ++output
    test r12, r12
    jnz .process_line
    inc qword [output]
    jmp .process_line

.done:
    ; print the answer
    mov rdi, [output]
    call _write_int

    ret

section .data
%include "01/input.inc"

section .bss
output: resb 8