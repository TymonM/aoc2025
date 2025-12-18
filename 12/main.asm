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

; read present shapes into shape_sizes
; returns rdi = cursor to first line of scenarios
_init:
    ; rdi is input cursor
    ; rsi is shape_sizes cursor
    ; rcx is remaining shapes
    lea rdi, [input]
    lea rsi, [shape_sizes]
    mov rcx, num_shapes

.loop:
    xor rdx, rdx ; current shape size

    push rsi
    push rcx
    call _read_int ; read the label "0:" etc
    pop rcx
    pop rsi

    inc rdi ; skip colon
    inc rdi ; skip newline

    mov r8, 9 ; number of cells left to read
.read_shape:
    cmp byte [rdi], '#'
    jne .next_cell
    inc rdx ; increment size counter
.next_cell:
    cmp byte [rdi], 10 ; newline
    jne .no_newline
    inc rdi
    jmp .read_shape
.no_newline:
    inc rdi
    dec r8
    jnz .read_shape

    ; store size
    mov qword [rsi], rdx
    add rsi, 8 ; advance `shape_sizes` cursor

    add rdi, 2 ; skip extra newlines

    dec rcx
    jnz .loop

    ret

_first:
    ; [rsp] contains width*height
    ; [rsp+8] contains (height/3)*(width/3)
    sub rsp, 16

    ; rcx contains current line index
    mov rcx, 5*num_shapes ; due to `_init`

.loop:
    cmp rcx, input_lines
    jge .done

    ; read dimensions
    push rcx
    call _read_int

    ; r8 := width
    mov r8, rax
    inc rdi ; skip 'x'

    call _read_int
    ; r9 := height
    mov r9, rax
    inc rdi ; skip colon
    pop rcx

    ; initialise height/3, width/3 and width*height
    mov rax, r8
    imul rax, r9
    mov [rsp], rax

    xor rdx, rdx ; clear rdx for division
    mov rax, r8
    mov rbx, 3
    div rbx
    mov [rsp+8], rax
    xor rdx, rdx ; clear rdx for division
    mov rax, r9
    div rbx
    imul rax, [rsp+8]
    mov [rsp+8], rax

    ; from now on,
    ; r8 := total spaces
    ; r9 := total presents
    xor r8, r8
    xor r9, r9

    ; rdx = current shape index
    xor rdx, rdx
.shape_loop:
    cmp rdx, num_shapes
    jge .check_region

    inc rdi ; skip space
    push rcx
    call _read_int
    pop rcx

    ; total presents += cur
    add r9, rax

    ; total spaces += cur * sizes[cur]
    lea rsi, [shape_sizes]
    mov rsi, [rsi+8*rdx]
    imul rax, rsi

    add r8, rax

    inc rdx
    jmp .shape_loop

.check_region:
    cmp r8, [rsp]
    jge .trivially_impossible
    cmp r9, [rsp+8]
    jle .trivially_possible
    jmp .nontrivial
.trivially_possible:
    inc qword [output]
    jmp .next_region
.trivially_impossible:
.next_region:
    inc rdi ; skip newline
    inc rcx
    jmp .loop

.done:
    mov rdi, [output]
    call _write_int

    add rsp, 16
    ret

.nontrivial:
    mov rax, 0x2000004 ; write syscall
    mov rdi, 1
    lea rsi, [nontrivial_message]
    mov rdx, nontrivial_message_size
    syscall

    add rsp, 16
    ret

section .data
%include "12/input.inc"
nontrivial_message: db "There exist nontrivial regions :(", 10
nontrivial_message_size equ $ - nontrivial_message

section .bss
output: resb 8
shape_sizes: resq num_shapes