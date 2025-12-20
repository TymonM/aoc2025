; This file contains functions for Integer Linear Programming
; Why is this not in `utils.asm`? Because it is hugeeee and sort of a separate project at this point

; NASM syntax (Intel) for macOS x86_64

default rel

section .text
global _prepare_big_m

; creates artificial variables and scale them in the objective function
; rdi = pointer to tableau
_prepare_big_m:
    mov r8, rdi

   ; rcx := the current row we are creating artificial
   ;    variables for
    mov rcx, 0

.row_loop:
    cmp rcx, [r8] ; if cur_row >= height: break
    jge .created_artifical_variables

    ; rdx := offset of value in this row
    ; rdi := cursor in [tableau]
    mov rdx, 0
    lea rdi, [r8+16] ; skip first two qwords
    mov rax, rcx
    imul rax, 400 ; number of bytes per row = 50*8
    add rdi, rax ; rdi := &start of row
    mov rax, [r8+8] ; `width`
    lea rdi, [rdi+8*rax]

; sets the diagonal (artifical vars) to 1.0 and the rest to 0.0
.cell_loop:
    cmp rdx, [r8]
    jge .next_row
    cmp rdx, rcx
    setz al
    movzx rax, al
    cvtsi2sd xmm0, rax
    movsd [rdi], xmm0
    add rdi, 8

    inc rdx
    jmp .cell_loop

.next_row:
    inc rcx
    jmp .row_loop

.created_artifical_variables:
    ; update the `width` parameter of the tableau
    mov rax, [r8]
    add qword [r8+8], rax

    ret

section .data
big_m: dq 100.0

section .bss
; a tableau is stored in memory as 2653 qwords:
; - the first 2 qwords are the `height` and `width` respectively, as u64
; - the next 50*50 qwords represent coefficients of 50 rows of constraints, each with 50 variables.
;       the variables are stored as f64 doubles
; - the next 50 qwords represent the 'outputs' of the constraints, as f64
; - the next 50 qwords represent the 'corresponding columns' for each row
; - the next 50 qwords represent the coefficients of the objective function (to **maximize**), they
;       are also stored as f64
; - the last qword is an f64 for the 'output' of the objective function
tmp_tableau: resq 2 + 50*50 + 50 + 50 + 50 + 1