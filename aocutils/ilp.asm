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
    jge .add_to_objective

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

; subtract all M*a_i from objective for all artificial variables
.add_to_objective:
    ; rdi is cursor in objective of tableau
    ; rcx is counter of remaining values to update
    mov rdi, r8
    add rdi, (2+50*50+50+50)*8
    mov rax, [r8+8] ; width
    lea rdi, [rdi+8*rax]
    mov rcx, [r8]

    ; xmm0 := -M
    movsd xmm0, [big_m]
    movabs rax, 0x8000000000000000
    movq xmm1, rax
    xorpd xmm0, xmm1

.objective_loop:
    movq [rdi], xmm0
    add rdi, 8
    dec rcx
    jnz .objective_loop

    ; update the `width` parameter of the tableau
    mov rax, [r8]
    add qword [r8+8], rax

    ; TODO: make elimination a separate call, automatically
    ;   also eliminating outputs, too
    ; eliminate the new `M`s in the objective
    ; rcx is current row we are eliminating
    xor rcx, rcx
.eliminate_row:
    cmp rcx, [r8]
    jge .eliminate_output

    ; rdi is constraints cursor
    ; rsi is objective cursor
    ; rdx is counter of remaining values in this row
    mov rdi, r8
    add rdi, 16 ; skip `width` and `height`
    mov rax, rcx
    imul rax, 400 ; 400 bytes per row
    add rdi, rax
    mov rsi, r8
    add rsi, (2+50*50+50+50)*8
    mov rdx, [r8+8] ; there are `width` values in each row

.eliminate_cell:
    movsd xmm0, [rdi]
    movsd xmm1, [big_m]
    mulsd xmm0, xmm1
    movsd xmm1, [rsi]
    addsd xmm1, xmm0
    movsd [rsi], xmm1

    add rdi, 8
    add rsi, 8
    dec rdx
    jnz .eliminate_cell

    inc rcx
    jmp .eliminate_row

.eliminate_output:
    ; rdi is row output cursor
    ; xmm1 is objective output
    ; rcx is counter of remaining rows
    ; xmm0 contains M
    lea rdi, [r8+(2+50*50)*8]
    movsd xmm1, [r8+(2+50*50+150)*8]
    mov rcx, [r8]
    movsd xmm0, [big_m]
.eliminate_output_loop:
    movsd xmm2, [rdi]
    mulsd xmm2, xmm0
    addsd xmm1, xmm2
    add rdi, 8
    dec rcx
    jnz .eliminate_output_loop

    movsd [r8+(2+50*50+150)*8], xmm1

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