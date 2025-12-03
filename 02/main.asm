; NASM syntax (Intel) for macOS x86_64
default rel

extern _to_string
extern _write_int
extern _read_int
extern _memcmp

section .text
global _start

_start:
    call _first
    call _second

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

_first:
    mov qword [output], 0 ; accumulator for answer
    mov r8, input_ranges ; count how many ranges remaining
    lea r9, [input] ; input reading cursor
.process_range:
    mov rdi, r9
    call _read_range
    mov r9, rdi ; update cursor

    mov rcx, rdx
    mov r10, rax
.range_loop:
    push rcx
    push r8
    mov rdi, rcx
    lea rsi, [string_buffer]
    call _to_string ; the string is now at string_buffer
    pop r8
    pop rcx

    test rax, 1 ; if (rax & 1)
    jnz .range_loop_end ; odd length is definitely valid id

    push rcx
    push r8
    
    shr rax, 1 ; half length
    lea rdi, [string_buffer]
    lea rsi, [string_buffer]
    add rsi, rax
    mov rdx, rax
    call _memcmp ; compare first and second halves

    pop r8
    pop rcx

    test rax, rax
    jnz .range_loop_end

    ; found invalid id
    add [output], rcx
.range_loop_end:
    inc rcx
    cmp rcx, r10
    jle .range_loop

    inc r9 ; advance cursor to skip delimeter
    dec r8
    jnz .process_range

.done:
    mov rdi, [output]
    call _write_int
    ret

_second:
    mov qword [output], 0 ; accumulator for answer
    mov r8, input_ranges ; count how many ranges remaining
    lea r9, [input] ; input reading cursor
.process_range:
    mov rdi, r9
    call _read_range
    mov r9, rdi ; update cursor

    mov rcx, rdx
    mov r10, rax
.range_loop:
    push rcx
    push r8
    mov rdi, rcx
    lea rsi, [string_buffer]
    call _to_string ; the string is now at string_buffer

    push r9
    push r10
    mov rdi, rax ; string length
    call _try_all_periods
    pop r10
    pop r9
    pop r8
    pop rcx

    test rax, rax
    jz .range_loop_end

    ; found invalid id
    add [output], rcx
.range_loop_end:
    inc rcx
    cmp rcx, r10
    jle .range_loop

    inc r9 ; advance cursor to skip delimeter
    dec r8
    jnz .process_range

.done:
    mov rdi, [output]
    call _write_int
    ret

; reads a XXX-YYY range pointed to by rdi
; returns
;   rax = YYY
;   rdx = XXX
_read_range:
    call _read_int
    mov rdx, rax
    inc rdi ; skip comma
    call _read_int
    ret

; checks if string_buffer is periodic with any period
; rdi = length of string buffer
; returns rax = 1 if periodic and 0 otherwise
_try_all_periods:
    mov r8, rdi ; length
    mov rcx, 1 ; current period to check
.loop:
    cmp rcx, r8
    jge .aperiodic

    ; check if length % period == 0
    xor rdx, rdx
    mov rax, r8
    div rcx
    test rdx, rdx
    jnz .loop_end

    push r8
    push rcx
    mov rdi, rcx
    lea rsi, [string_buffer]
    add rsi, r8 ; end of string
    call _try_period
    pop rcx
    pop r8
    test rax, rax
    jz .loop_end

    ret ; IT'S PERIODIC!!
.loop_end:
    inc rcx
    jmp .loop

.aperiodic:
    xor rax, rax ; ret 0
    ret

; check if string_buffer is periodic with specific period
; rdi = period
; rsi = string end
; returns rax = 1 if periodic and 0 otherwise
_try_period:
    mov r8, rdi ; period
    mov r9, rsi ; string end
    lea rdi, [string_buffer]
    lea rsi, [string_buffer]
    add rsi, r8
.loop:
    cmp rsi, r9
    jge .periodic

    push r8
    push r9
    push rdi
    push rsi
    mov rdx, r8
    call _memcmp
    pop rsi
    pop rdi
    pop r9
    pop r8
    test rax, rax
    jnz .aperiodic

    add rsi, r8
    jmp .loop

.periodic:
    mov rax, 1 ; ret 1
    ret
.aperiodic:
    xor rax, rax ; ret 0
    ret


section .data
%include "02/input.inc"

section .bss
output: resb 8
string_buffer: resb 32