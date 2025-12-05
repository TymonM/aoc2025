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

; reads into ranges and queries
_init:
    mov rcx, input_lines ; lines remaining counter
    lea rdi, [input]
    lea rsi, [ranges]
.read_range:
    cmp byte [rdi], 10 ; newline, ranges are done
    je .done_ranges
    push rcx
    call _read_int
    mov [rsi], rax
    add rsi, 8
    inc rdi ; skip hyphen
    call _read_int
    mov [rsi], rax
    add rsi, 8
    inc rdi ; skip newline
    pop rcx
    dec rcx
    jmp .read_range
.done_ranges:
    ; count ranges
    mov rax, input_lines
    sub rax, rcx
    imul rax, 16 ; 16 bytes per range (two qwords)
    mov [ranges_bytes], rax

    inc rdi ; skip newline
    dec rcx
    lea rsi, [queries]
.read_query:
    push rcx
    call _read_int
    mov [rsi], rax
    add rsi, 8
    inc rdi ; skip newline
    pop rcx
    dec rcx
    jnz .read_query

    ; count queries
    mov rax, input_lines
    imul rax, 16 ; 16 bytes per line
    sub rax, [ranges_bytes] ; only non-range lines
    shr rax, 1 ; the remaing lines are only 8 bytes
    sub rax, 8 ; the newline is not a query
    mov [query_bytes], rax
    ret

_first:
    mov qword [output], 0
    ; rcx contains pointer to current query, rdx contains pointer to current range half
    mov rcx, 0
.check_query:
    ; rax = x
    lea rdi, [queries]
    add rdi, rcx
    mov rax, [rdi]
    mov rdx, 0
.check_range:
    ; r8 = lower
    ; mov r8, [ranges + rdx]
    lea rdi, [ranges]
    add rdi, rdx
    mov r8, [rdi]
    cmp rax, r8
    jl .next_range_and_skip ; if x < lower
    add rdx, 8
    ; r8 = upper
    ; mov r8, [ranges + 8*rdx]
    lea rdi, [ranges]
    add rdi, rdx
    mov r8, [rdi]
    cmp rax, r8
    jg .next_range ; if x > upper
    add rdx, 8
    inc qword [output]
    jmp .next_query
.next_range_and_skip:
    add rdx, 8 ; because we bailed on lower, we still need to skip past upper
.next_range:
    add rdx, 8
    cmp rdx, [ranges_bytes]
    jl .check_range ; we still have more ranges to check
.next_query:
    add rcx, 8 ; query was 8 bytes
    cmp rcx, [query_bytes]
    jl .check_query

    mov rdi, [output]
    call _write_int
    ret


section .data
%include "05/input.inc"

section .bss
output: resb 8
ranges: resq 2*input_lines ; qword for L and for R
queries: resq input_lines ; qword for x
ranges_bytes: resb 8
query_bytes: resb 8