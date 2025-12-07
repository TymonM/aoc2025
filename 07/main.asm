; NASM syntax (Intel) for macOS x86_64
default rel

extern _memset
extern _write_int

section .text
global _start

_start:
    call _first
    call _second

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

; we use a push dp on 'set' columns
_first:
    mov qword [output], 0 ; split counter
    call _clear_dp

    ; rdi contains input cursor
    ; rsi contains dp cursor
    ; rcx contains remaining rows
    ; rdx contains column
    lea rdi, [input]
    lea rsi, [dp]
    mov rcx, height-1

.read_row:
    mov rdx, 0
.read_col:
    lea r8, [rsi + 8*width] ; next line of dp
    mov r9, [rsi] ; store current dp value in register
    cmp byte [rdi], 'S'
    je .source
    cmp byte [rdi], '^'
    je .split
    ; otherwise, fallthrough
    or [r8], r9
    jmp .step_col
.source:
    mov qword [r8], 1
    jmp .step_col
.split:
    add [output], r9 ; output += (canreach?)
    or qword [r8-8], r9
    or qword [r8+8], r9
    mov [r8], 0
.step_col:
    inc rdi
    add rsi, 8
    inc rdx
    cmp rdx, width
    jl .read_col

    inc rdi ; skip newline
    dec rcx
    jnz .read_row

    mov rdi, [output]
    call _write_int
    ret

; basically the same as first except we add instead of ORing
_second:
    mov qword [output], 0 ; timeline counter
    call _clear_dp

    ; rdi contains input cursor
    ; rsi contains dp cursor
    ; rcx contains remaining rows
    ; rdx contains column
    lea rdi, [input]
    lea rsi, [dp]
    mov rcx, height-1

.read_row:
    mov rdx, 0
.read_col:
    lea r8, [rsi + 8*width] ; next line of dp
    mov r9, [rsi] ; store current dp value in register
    cmp byte [rdi], 'S'
    je .source
    cmp byte [rdi], '^'
    je .split
    ; otherwise, fallthrough
    add [r8], r9
    jmp .step_col
.source:
    mov qword [r8], 1
    inc [output]
    jmp .step_col
.split:
    ; output += (wayscanreach), since that's the number of timelines created
    add [output], r9
    add [r8-8], r9
    add [r8+8], r9
    mov [r8], 0
.step_col:
    inc rdi
    add rsi, 8
    inc rdx
    cmp rdx, width
    jl .read_col

    inc rdi ; skip newline
    dec rcx
    jnz .read_row

    mov rdi, [output]
    call _write_int
    ret

; clear the dp table, resetting it to all zero
_clear_dp:
    lea rdi, [dp]
    mov sil, 0x0
    mov rdx, input_cells * 8
    call _memset

    ret

section .data
%include "07/input.inc"

section .bss
output: resb 8
dp: resq input_cells
