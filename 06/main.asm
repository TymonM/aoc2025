; NASM syntax (Intel) for macOS x86_64
default rel

extern _memset
extern _read_int
extern _write_int

section .text
global _start

_start:
    call _init
    call _first
    call _second

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

; reads problems and operations
_init:
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

    ; now read the operations
    ; rsi points to `operations` and rdi is input cursor
    ; rdi reused from problem reading
    lea rsi, [operations]
.seek_operation:
    cmp byte [rdi], 32 ; space
    jne .found_operation
    inc rdi
    jmp .seek_operation
.found_operation:
    cmp [rdi], 10 ; if hit newline
    je .done
    ; else copy the operation over
    mov r8b, [rdi]
    mov byte [rsi], r8b
    inc rsi
    inc rdi
    jmp .seek_operation

.done:
    ret

_first:
    mov qword [output], 0 ; total ans

    ; rax contains current problem total
    ; rdi points to current problem base in `problems`
    ; rsi is cursor in `operations`
    ; rcx contains remaining values in this problem
    ; rdx contains remaining problems
    lea rdi, [problems]
    lea rsi, [operations]
    mov rdx, problem_count
.eval_loop:
    mov rcx, input_lines-1
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
    inc rsi ; go to next operation
    lea rdi, [rdi+8*(input_lines-1)] ; step `problems` base
    dec rdx
    jnz .eval_loop

    ; print output
    mov rdi, [output]
    call _write_int
    ret

_second:
    mov qword [output], 0 ; total ans
    call _transpose_input

    ; r8 contains current problem's total
    ; rdi contains our cursor in transposed input
    ; rsi contains our `operations` cursor
    ; rdx contains remaining problem count
    lea rdi, [transposed_input]
    lea rsi, [operations]
    mov rdx, problem_count
.eval_problem:
    cmp byte [rsi], '+'
    je .init_plus
    mov r8, 1 ; multiplicative identity
    jmp .seek
.init_plus:
    mov r8, 0 ; additive identity

.seek:
    ; we look for an integer, or until we hit a 0x0 (empty line)
    cmp byte [rdi], 0
    je .done_problem
    cmp byte [rdi], 32 ; space
    jne .found_int
    inc rdi
    jmp .seek
.found_int:
    call _read_int
    cmp byte [rsi], '+'
    je .apply_plus
    imul r8, rax
    jmp .seek_newline
.apply_plus:
    add r8, rax
.seek_newline:
    ; now, since we DID find an integer, this is not a newline, so we need to skip past the next 0x0
    ; 'newline' here refers to 0x0 which might be confusing...
    cmp byte [rdi], 0
    je .continue_problem
    inc rdi
    jmp .seek_newline
.continue_problem:
    inc rdi ; skip newline (i.e. 0x0)
    jmp .seek

.done_problem:
    add [output], r8
    inc rdi ; skip newline
    inc rsi ; next operation
    dec rdx
    jnz .eval_problem

    ; we are finally done!
    mov rdi, [output]
    call _write_int
    ret

; copies the input bytes for the problems (not the operations)
;   such that (i,j) contains the byte at (j,i)
; since we don't copy the operations, we replace the with a 0 char so that we can detect
;   endline
_transpose_input:
    ; transposed_input[*] = 0
    lea rdi, [transposed_input]
    mov sil, 0
    mov rdx, input_bytes
    call _memset

    ; rdi will contain our input cursor
    ; rsi will contain our transposed_input cursor
    ; rcx contains the index of the line we are transposing
    lea rdi, [input]
    lea rsi, [transposed_input]
    mov rcx, 0
.transpose_line:
    cmp rcx, input_lines-1
    jge .done
.copy_char:
    cmp byte [rdi], 10 ; newline
    je .endline
    mov r8b, [rdi]
    mov byte [rsi], r8b
    ; now we step once in the normal version but input_lines in the transposed version
    inc rdi
    lea rsi, [rsi+1*input_lines]
    jmp .copy_char
.endline:
    inc rdi
    lea rsi, [transposed_input]
    inc rcx
    lea rsi, [rsi + 1*rcx]
    jmp .transpose_line
.done:
    ret

section .data
%include "06/input.inc"

section .bss
output: resb 8
problems: resq problem_count * (input_lines-1)
operations: resb problem_count
transposed_input: resb input_bytes
