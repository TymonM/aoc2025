; NASM syntax (Intel) for macOS x86_64
default rel

extern _memset
extern _write_int

section .text
global _start

_start:
    call _init
    call _first

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

; init copies the grid and pads it with empty cells
; this makes checking neighbours wayyy easier later
; the grid is created at grid_copy
_init:
    ; rax = size of new grid
    mov rax, input_bytes
    add rax, height
    add rax, width
    add rax, width
    add rax, 4

    ; clear bss space for the new grid
    lea rdi, [grid_copy]
    mov sil, '.'
    mov rdx, rax
    call _memset

    lea rdi, [grid_copy] ; point to start of new grid
    add rdi, width
    add rdi, 3 ; point to UL corner
    mov rsi, rdi
    add rsi, input_bytes ; move rsi to DR corner
    sub rsi, height ; newlines don't count

    ; rcx = x, rdx = y
    mov rcx, 0
    mov rdx, 0

.loop:
    ; rax = original memory location
    lea rax, [input]
    mov r8, rdx
    imul r8, width+1
    add rax, r8
    add rax, rcx

    ; rbx = new memory location
    mov rbx, rdi
    mov r8, rdx
    imul r8, width+2
    add rbx, r8
    add rbx, rcx

    ; copy byte
    mov r8b, byte [rax]
    mov byte [rbx], r8b

    inc rcx
    cmp rcx, width
    jl .loop
    xor rcx, rcx ; reset x
    inc rdx ; next row
    cmp rdx, height
    jl .loop
.done:
    ret

_first:
    mov qword [output], 0 ; counter

    sub rsp, 16 ; dx and dy counters

    ; rcx = x, rdx = y
    mov rcx, 0
    mov rdx, 0
    ; rdi = cursor
    lea rdi, [grid_copy]
    add rdi, width + 3 ; move to UL
.loop:
    mov al, byte [rdi]
    cmp al, '@'
    jne .step_loop

    mov qword [rsp], -1 ; dx = -1
    mov qword [rsp+8], -1 ; dy = -1
    xor r8, r8 ; neighbour count = 0
.scan_neighbours:
    mov rax, [rsp+8] ; dy
    imul rax, width + 2
    add rax, [rsp] ; dx
    cmp byte [rdi + rax], '@'
    jne .step_scan_neighbours
    inc qword r8
.step_scan_neighbours:
    inc qword [rsp]
    cmp [rsp], 1
    jle .scan_neighbours
    mov qword [rsp], -1 ; reset dx
    inc qword [rsp+8] ; dy
    cmp [rsp+8], 1
    jle .scan_neighbours
.finish_neighbours:
    ; if neigh < 5, ++output
    ; note that 5 because we also count itself
    cmp r8, 5
    jge .step_loop
    inc qword [output]

.step_loop:
    inc rdi ; step cursor
    inc rcx ; ++x
    cmp rcx, width ; if x == width
    jl .loop
    xor rcx, rcx ; reset x
    add rdi, 2 ; increment cursor past padding
    inc rdx ; next row (++y)
    cmp rdx, height
    jl .loop
.done:
    add rsp, 16
    mov rdi, [output]
    call _write_int
    ret

section .data
%include "04/input.inc"

section .bss
output resb 8
grid_copy resb (width + 2) * (height + 2)
