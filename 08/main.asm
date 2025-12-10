; NASM syntax (Intel) for macOS x86_64
default rel

extern _memset
extern _memsetq
extern _read_int
extern _write_int
extern _quickselect
extern _dsu_find
extern _dsu_join

section .text
global _start

_start:
    call _init
    call _first

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

; read points and initialise index_pairs
; also reset the dsu
_init:
    ; init dsu.parents
    lea rdi, [dsu_parent]
    mov sil, 0xFF
    mov rdx, input_lines*8
    call _memset

    ; init dsu.sizes to all 1
    lea rdi, [dsu_size]
    mov rsi, 1
    mov rdx, input_lines
    call _memsetq

    ; set up index_pairs and pointers
    ; rdi and rsi are cursors, rcx and rdx are current pair indices
    lea rdi, [index_pairs]
    lea rsi, [index_pair_pointers]
    mov rcx, 0 ; contains first of pair
.index_pair_loop:
    cmp rcx, input_lines-1
    jge .done_index_pairs
    mov rdx, rcx
    inc rdx ; start from rcx+1, the next point, to avoid double counting
.inner_index_pair_loop:
    cmp rdx, input_lines
    jge .step_index_pair_loop
    mov [rdi], rcx ; first of pair
    mov [rdi+8], rdx ; second of pair
    mov [rsi], rdi ; pointer
    add rdi, 16
    add rsi, 8
    inc rdx
    jmp .inner_index_pair_loop
.step_index_pair_loop:
    inc rcx
    jmp .index_pair_loop

.done_index_pairs:
    ; now we read in points from the input
    ; rdi = input cursor
    ; rcx = remaining values
    ; rsi = `points` cursor
    lea rdi, [input]
    mov rcx, 3*input_lines
    lea rsi, [points]
.read_points_loop:
    push rcx
    call _read_int
    mov [rsi], rax ; store value
    inc rdi ; skip comma or newline
    add rsi, 8
    pop rcx
    dec rcx
    jnz .read_points_loop

    ret

_first:
    call _calc_weights

    ; keep only the top `steps` shortest weights
    lea rdi, [weights]
    lea rsi, [index_pair_pointers]
    mov rdx, input_lines*(input_lines-1)/2
    mov rcx, steps
    call _quickselect ; partition first `steps` pairs to beginning

    ; execute the joins
    ; rcx = current join
.join_loop:
    cmp rcx, steps
    jge .done_joining

    push rcx

    ; rdx := &(p1, p2)
    lea rdx, [index_pair_pointers]
    mov rdx, [rdx+8*rcx]

    ; do the join
    lea rdi, [dsu_parent]
    lea rsi, [dsu_size]
    mov rcx, [rdx+8]
    mov rdx, [rdx]
    call _dsu_join

    pop rcx
    inc rcx
    jmp .join_loop

.done_joining:
    ; negate the dsu component sizes, so that sorting puts them in descending order
    ; also, set non root sizes to 0
    ; rdi = dsu_size cursor
    ; rsi = dsu_parent cursor
    ; rcx = remaining iterations
    lea rdi, [dsu_size]
    lea rsi, [dsu_parent]
    mov rcx, input_lines
.prepare_sizes_loop:
    cmp [rsi], -1
    je .is_root
    mov qword [rdi], 0
.is_root:
    neg qword [rdi]

    ; loop back
    add rdi, 8
    add rsi, 8
    dec rcx
    jnz .prepare_sizes_loop

    ; pick the top `top` sizes
    lea rdi, [dsu_size]
    lea rsi, [dsu_parent] ; trash satellite data
    ; note the dsu is now completely invalidated, but we don't need it anymore
    mov rdx, input_lines
    mov rcx, top
    call _quickselect

    mov rax, 1 ; product

    ; rdi = base [dsu_size]
    ; rcx = currently processed size
    lea rdi, [dsu_size]
    mov rcx, 0
.answer_product_loop:
    cmp rcx, top
    jge .done

    mov r8, [rdi+8*rcx]
    neg r8 ; flip sign back to positive
    imul rax, r8
    inc rcx
    jmp .answer_product_loop
.done:
    mov [output], rax
    mov rdi, [output]
    call _write_int

    ret

; calculate the weights for each pair of indices
; weights are equal to square euclidean distance
_calc_weights:
    ; rdi contains our `weights` cursor
    ; rsi contains `points`.end dummy so we know when to stop
    ; rcx contains first point cursor
    ; rdx contains second point cursor
    lea rdi, [weights]
    lea rsi, [points]
    add rsi, input_lines*3*8
    lea rcx, [points]
.rcx_loop:
    cmp rcx, rsi
    jge .done
    mov rdx, rcx
    add rdx, 24 ; start from the next point
.rdx_loop:
    cmp rdx, rsi
    jge .step_rcx_loop
    
    ; calculate euclidean distance (squared)
    xor rax, rax
    mov r8, [rcx]
    sub r8, [rdx]
    imul r8, r8
    add rax, r8 ; rax += dx^2
    mov r8, [rcx+8]
    sub r8, [rdx+8]
    imul r8, r8
    add rax, r8 ; rax += dy^2
    mov r8, [rcx+16]
    sub r8, [rdx+16]
    imul r8, r8
    add rax, r8 ; rax += dz^2
    
    ; store the weight
    mov [rdi], rax
    add rdi, 8
    add rdx, 24

    jmp .rdx_loop

.step_rcx_loop:
    add rcx, 24
    jmp .rcx_loop

.done:
    ret


section .data
%include "08/input.inc"

section .bss
output: resb 8
dsu_parent: resq input_lines
dsu_size: resq input_lines
points: resq input_lines*3
index_pairs: resq input_lines*(input_lines-1) ; 2 qwords for each pair, but only n(n-1)/2 pairs
index_pair_pointers: resq input_lines*(input_lines-1)/2
weights: resq input_lines*(input_lines-1)/2