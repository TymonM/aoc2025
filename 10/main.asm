; NASM syntax (Intel) for macOS x86_64
default rel

extern _read_int
extern _write_int
extern _memcpy
extern _prepare_big_m

section .text
global _start

_start:
    call _init
    call _first
    call _second

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

; init reads machines into `targets` and `buttons`
_init:
    sub rsp, 24
    ; rdi is input cursor
    ; [rsp] is current line index
    ; [rsp+8] is `buttons` cursor
    ; [rsp+16] is current machine button count
    lea rdi, [input]
    mov qword [rsp], 0
    lea rax, [buttons]
    mov qword [rsp+8], rax

.readline:
    cmp qword [rsp], input_lines
    jge .done

    call _read_target ; into rax

    lea rbx, [targets]
    mov rcx, [rsp]
    lea rbx, [rbx+8*rcx]
    mov [rbx], rax ; save target

    inc rdi ; skip space

    mov qword [rsp+16], 0 ; clear button counter
    add qword [rsp+8], 8 ; reserve space for buttons
.buttonloop:
    cmp byte [rdi], '{'
    je .finished_buttons

    call _read_button

    mov rcx, [rsp+16]
    mov rdx, [rsp+8]
    lea rdx, [rdx+8*rcx]
    mov [rdx], rax ; save the button

    inc qword [rsp+16] ; button counter

    inc rdi ; skip space
    jmp .buttonloop

.finished_buttons:
    mov rcx, [rsp+16] ; button count
    mov rdx, [rsp+8] ; button cursor
    sub rdx, 8
    mov [rdx], rcx ; store button count
    imul rcx, 8
    add [rsp+8], rcx ; advance `buttons` cursor

    ; skip reading the joltage requirements
.seek_endline:
    cmp byte [rdi], 10
    je .next_line
    inc rdi
    jmp .seek_endline

.next_line:
    inc rdi ; skip newline
    inc qword [rsp]
    jmp .readline

.done:
    add rsp, 24
    ret

; reads a [...#.#] into a bitmask
; rdi = input cursor (will be advanced to first char after `]`)
; returns rax = target bitmask
_read_target:
    xor rax, rax
    inc rdi ; skip open brace
    
    mov rcx, 1 ; current bit we are setting
.loop:
    cmp byte [rdi], ']'
    je .done

    cmp byte [rdi], '.'
    je .nextbyte
    or rax, rcx ; set the bit
.nextbyte:
    inc rdi
    shl rcx, 1 ; we're setting the next bit
    jmp .loop

.done:
    inc rdi ; skip closing brace
    ret

; reads a (0,3,4) into a bitmask
; rdi = input cursor (will be advanced to first char after `)`)
; returns rax = button bitmask
_read_button:
    xor rcx, rcx ; rcx will be output

    inc rdi ; skip open paren
.loop:
    push rcx
    call _read_int
    pop rcx
    bts rcx, rax

    cmp byte [rdi], ')'
    je .done
    inc rdi ; skip comma
    jmp .loop

.done:
    inc rdi ; skip closing paren
    mov rax, rcx
    ret

_first:
    mov qword [output], 0 ; acc

    ; [rsp] contains current min
    ; [rsp+8] contains current target
    ; [rsp+16] contains current button count
    sub rsp, 24

    ; rcx contains current machine/line index
    ; rdi contains current `buttons` base pointer
    mov rcx, 0
    lea rdi, [buttons]
.main_loop:
    cmp rcx, input_lines
    jge .done

    ; current min := INFINITY
    mov qword [rsp], 42

    ; [rsp+8] := current target
    lea rax, [targets]
    lea rax, [rax+8*rcx]
    mov rax, [rax]
    mov [rsp+8], rax

    ; set base pointer and button count
    mov rax, [rdi]
    mov [rsp+16], rax
    add rdi, 8

    ; rdx contains current button mask
    ; rsi contains current output of the buttons
    ; r8 contains the current iteration
    xor rdx, rdx
    xor rsi, rsi
    mov r8, 1
.subset_loop:
    cmp rsi, [rsp+8]
    jne .notarget
    ; current min = min(current min, popcount(mask))
    popcnt rax, rdx
    mov rbx, [rsp]
    cmp rax, rbx
    cmovl rbx, rax
    mov [rsp], rbx
.notarget:
    mov rax, [rsp+16]
    bt r8, rax ; if we've tested all the masks
    jc .step_main_loop
    
    ; advance the mask
    ; we use the Gray code rule msk^=i&(-i)
    tzcnt rax, r8
    xor rsi, [rdi+8*rax] ; use the `rax`th button
    btc rdx, rax ; flip the `rax`th bit in the mask

    inc r8
    jmp .subset_loop

.step_main_loop:
    inc rcx
    mov rax, [rsp+16]
    lea rdi, [rdi+8*rax] ; advance `buttons` pointer

    mov rax, [rsp]
    add [output], rax
    jmp .main_loop

.done:
    mov rdi, [output]
    call _write_int

    add rsp, 24
    ret

_second:
    lea rdi, [test_tableau]
    lea rsi, [tableau]
    mov rdx, 2653*8
    call _memcpy

    lea rdi, [tableau]
    call _prepare_big_m

    ; print dimensions for test
    lea rax, [tableau]
    mov rdi, [rax]
    call _write_int
    lea rax, [tableau]
    add rax, 8
    mov rdi, [rax]
    call _write_int

    ret

section .data
%include "10/input.inc"
test_tableau:
    dq 4, 6
    dq 0.0, 0.0, 0.0, 0.0, 1.0, 1.0
    times 44 dq 0.0
    dq 0.0, 1.0, 0.0, 0.0, 0.0, 1.0
    times 44 dq 0.0
    dq 0.0, 0.0, 1.0, 1.0, 1.0, 0.0
    times 44 dq 0.0
    dq 1.0, 1.0, 0.0, 1.0, 0.0, 0.0
    times 44 dq 0.0
    times 2300 dq 0.0
    dq 3.0, 5.0, 4.0, 7.0
    times 96 dq 0.0
    dq -1.0, -1.0, -1.0, -1.0, -1.0, -1.0
    times 45 dq 0.0

section .bss
output: resb 8
targets: resq input_lines ; one bitmask per machine
; we store buttons in a compressed array
;   For each machine, first is stored one qword S representing that S buttons
;   follow. The next S qwords are a qword bitmask for each button
buttons: resq input_lines*10
tableau: resq 2 + 50*50 + 50 + 50 + 50 + 1
