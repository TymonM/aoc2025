; NASM syntax (Intel) for macOS x86_64
default rel

extern _read_int
extern _write_int
extern _sort

section .text
global _start

_start:
    call _init
    call _first
    call _second

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

; reads into ranges and queries
_init:
    mov rcx, input_lines ; lines remaining counter
    lea rdi, [input]
    lea rsi, [range_lefts]
    lea rdx, [range_rights]
.read_range:
    cmp byte [rdi], 10 ; newline, ranges are done
    je .done_ranges
    push rcx
    call _read_int
    mov [rsi], rax
    add rsi, 8
    inc rdi ; skip hyphen
    call _read_int
    mov [rdx], rax
    add rdx, 8
    inc rdi ; skip newline
    pop rcx
    dec rcx
    jmp .read_range
.done_ranges:
    ; count ranges
    mov rax, input_lines
    sub rax, rcx
    imul rax, 8 ; 8 bytes per range (one qword)
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
    imul rax, 8 ; 8 bytes per line
    sub rax, [ranges_bytes] ; only non-range lines
    sub rax, 8 ; the newline is not a query
    mov [query_bytes], rax
    ret

_first:
    mov qword [output], 0
    ; rcx contains offset to current query, rdx contains offset to current range
    mov rcx, 0
.check_query:
    ; rax = x
    lea rdi, [queries]
    add rdi, rcx
    mov rax, [rdi]
    mov rdx, 0
.check_range:
    ; r8 = lower
    ; mov r8, [range_lefts + rdx]
    lea rdi, [range_lefts]
    add rdi, rdx
    mov r8, [rdi]
    cmp rax, r8
    jl .next_range ; if x < lower
    ; r8 = upper
    ; mov r8, [range_rights + rdx]
    lea rdi, [range_rights]
    add rdi, rdx
    mov r8, [rdi]
    cmp rax, r8
    jg .next_range ; if x > upper
    add rdx, 8
    inc qword [output]
    jmp .next_query
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

_second:
    mov qword [output], 0 ; acc

    ; rdx contains number of ranges
    mov rdx, [ranges_bytes]
    shr rdx, 3 ; 8 bytes per range

    ; sort ranges by left endpoint
    lea rdi, [range_lefts]
    lea rsi, [range_rights]
    call _sort

    ; rcx stores offset to current range
    mov rcx, 0

    ; rdx is our current right endpoint
    mov rdx, -1

.add_range:
    ; r8=lower, r9=upper
    lea rdi, [range_lefts]
    add rdi, rcx
    mov r8, [rdi]
    lea rdi, [range_rights]
    add rdi, rcx
    mov r9, [rdi]

    ; if lower > cur_r
    cmp r8, rdx
    jg .strictly_right
    mov r8, rdx
    inc r8 ; make it strictly right of rightmost endpoint
.strictly_right:
    mov r10, r9
    sub r10, r8
    inc r10 ; r10 now contains the size of the range
    cmp r10, 0
    jl .next_range
    add [output], r10
    mov rdx, r9 ; increase right endpoint
.next_range:
    add rcx, 8
    cmp rcx, [ranges_bytes]
    jl .add_range

    mov rdi, [output]
    call _write_int
    ret


section .data
%include "05/input.inc"

section .bss
output: resb 8
range_lefts: resq input_lines ; qword for L
range_rights: resq input_lines ; qword for R
queries: resq input_lines ; qword for x
ranges_bytes: resb 8
query_bytes: resb 8