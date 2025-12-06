; NASM syntax (Intel) for macOS x86_64
default rel

extern _read_int
extern _write_int

section .text
global _start

_start:
    call _first

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

_first:
    mov qword [output], 0 ; total ans

    ; read the problems into `problems` so that each problem is contiguous in memory
    ; rdi contians cursor into `input`
    ; rsi contains pointer into `problems`
    ; rcx contains current line
    ; rdx contains remaining problems on this line
    lea rdi, [input]
    mov rcx, 0
.read_line:
    lea rsi, [problems]
    lea rsi, [rsi+8*rcx] ; offset
    mov rdx, problem_count
.seek_int:
    cmp byte [rdi], 32 ; space
    jne .found_int
    inc rdi
    jmp .seek_int
.found_int:
    push rcx
    call _read_int
    pop rcx
    mov [rsi], rax
    dec rdx
    jz .finish_line
    lea rsi, [rsi + 8*(input_lines-1)] ; step `problems` pointer
    jmp .seek_int
.finish_line:
.seek_newline:
    cmp byte [rdi], 10 ; newline
    je .found_newline
    inc rdi
    jmp .seek_newline
.found_newline:
    inc rdi ; skip newline
    inc rcx
    cmp rcx, input_lines-1
    jl .read_line

    ; rax contains current problem total
    ; rdi points to current problem base in `problems`
    ; rsi is cursor in 'operations'
    ; rcx contains remaining values in this problem
    ; rdx contains remaining problems
    mov rsi, rdi ; reuse the cursor from problem copy loop
    lea rdi, [problems]
    mov rdx, problem_count
.eval_loop:
    mov rcx, input_lines-1
.seek_operation:
    ; look for a plus or a *
    cmp byte [rsi], 32 ; space
    jne .found_operation
    inc rsi
    jmp .seek_operation
.found_operation:
    cmp byte [rsi], '+'
    je .init_plus
    mov rax, 1 ; initialise as 1 = multiplicative identity
    jmp .problem_loop
.init_plus:
    mov rax, 0 ; initialise as 0 = additive identity
.problem_loop:
    ; r8 = cur
    mov r8, [rdi+8*rcx-8]
    cmp byte [rsi], '+'
    je .apply_plus
    imul rax, r8 ; rax *= cur
    jmp .step_problem_loop
.apply_plus:
    add rax, r8 ; rax += cur
.step_problem_loop:
    dec rcx
    jnz .problem_loop

    add [output], rax
    inc rsi ; skip this + or * char
    lea rdi, [rdi+8*(input_lines-1)] ; step `problems` base
    dec rdx
    jnz .eval_loop

    ; print outpue
    mov rdi, [output]
    call _write_int
    ret


section .data
%include "06/input.inc"

section .bss
output: resb 8
problems: resq problem_count * (input_lines-1)
