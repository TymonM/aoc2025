; NASM syntax (Intel) for macOS x86_64
default rel

extern _write_int
extern _read_int

section .text
global _start

_start:
    call _first
    call _second

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

_second:
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
    inc rdi ; skip 'R'
    push rcx
    call _read_int
    pop rcx
    inc rdi ; skip next newline char

    xor rdx, rdx
    mov r8, 100
    div r8 ; rax full, rdx remainder
    add [output], rax ; number of full rotations

    add r12, rdx ; rotate the dial
    cmp r12, 100
    jl .process_line

    ; overflow
    sub r12, 100
    inc qword [output]
    jmp .process_line

.left:
    inc rdi ; skip 'L'
    push rcx
    call _read_int
    pop rcx
    inc rdi ; skip next newline char

    xor rdx, rdx
    mov r8, 100
    div r8 ; rax full, rdx remainder
    add [output], rax ; number of full rotations

    ; if the dial is at 0, avoid double counting
    test r12, r12
    jnz .no_funky_double_count
    dec qword [output]
.no_funky_double_count:

    sub r12, rdx ; rotate the dial
    cmp r12, 0
    jg .process_line
    inc qword [output]
    test r12, r12
    jz .process_line
    add r12, 100 ; mod 100
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