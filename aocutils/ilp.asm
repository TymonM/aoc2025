; This file contains functions for Integer Linear Programming
; Why is this not in `utils.asm`? Because it is hugeeee and sort of a separate project at this point

; NASM syntax (Intel) for macOS x86_64

default rel

section .text
global _prepare_big_m
global _do_big_m

; creates artificial variables and scale them in the objective function
; rdi = pointer to tableau
_prepare_big_m:
    mov r8, rdi

   ; rcx := the current row we are creating artificial
   ;    variables for
    mov rcx, 0

.row_loop:
    cmp rcx, [r8] ; if cur_row >= height: break
    jge .append_to_objective

    ; rdx := offset of value in this row
    ; rdi := cursor in [tableau]
    mov rdx, 0
    lea rdi, [r8+16] ; skip first two qwords
    mov rax, rcx
    imul rax, 408 ; number of bytes per row = 51*8
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
.append_to_objective:
    ; rdi is cursor in objective of tableau
    ; rcx is counter of remaining values to update
    mov rdi, r8
    add rdi, (2+50*51)*8
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

    ; eliminate the new `M`s in the objective
    ; rcx is current row we are eliminating
    xor rcx, rcx
.eliminate_row:
    cmp rcx, [r8] ; if rcx >= `height`
    jge .done

    lea rdi, [r8 + 8*(2+50*51)] ; output := &objective
    mov rsi, r8
    add rsi, 16 ; skip `width` and `height`
    mov rax, rcx
    imul rax, 408 ; 51*8 bytes per row
    add rsi, rax
    mov rdx, 51 ; there are 51 values to eliminate in each row
    movsd xmm0, [big_m]
    call _eliminate

    inc rcx
    jmp .eliminate_row

.done:
    ret

; Maximize the objective function, subject to the **equality** constraints in the tableau, using the
;   big-M method
; The maximization is performed in-place, modifying the tableau
; Objective value can be extracted from `objective_output` after completion. WARNING: it will be negated!
; The solution can be recreated by looking at the `corresponding_columns` data
; rdi = pointer to tableau (should have been prepared by _prepare_big_m)
_do_big_m:
    mov r8, rdi

    ; [rsp] = pivot col
    ; [rsp+8] = pivot row
    sub rsp, 16

.main_loop:
    ; find column with most positive coefficient in the objective function
    ; xmm0 = current min coefficient value
    ; rdx = best column index
    ; rcx = current column we are considering
    ; rdi = objective cursor
    movsd xmm0, [neg_infty]
    mov rdx, 0
    mov rcx, 0
    lea rdi, [r8 + 8*(2+50*51)]
.max_column_loop:
    cmp rcx, 50
    jge .found_pivot_col

    movsd xmm1, [rdi]
    comisd xmm0, xmm1
    jae .next_column
    movsd xmm0, xmm1
    mov rdx, rcx
.next_column:
    add rdi, 8
    inc rcx
    jmp .max_column_loop

.found_pivot_col:
    ; if max <= 0, break since we are done maximizing
    movsd xmm1, [epsilon]
    comisd xmm0, xmm1
    jb .done

    ; look for min ratio
    ; xmm0 = current min ratio
    ; rdx is still pivot column index
    ; rdi = best row index
    ; rcx = current row we are considering
    ; rsi = base pointer to current row
    movsd xmm0, [infty]
    mov rdi, 0
    mov rcx, 0
    lea rsi, [r8 + 8*2]
.min_ratio_loop:
    cmp rcx, [r8]
    jge .found_min_ratio
    
    ; xmm1 := pivot value
    movsd xmm1, [rsi + 8*rdx]

    ; if pivot value <= 0, continue
    movsd xmm2, [epsilon]
    comisd xmm1, xmm2
    jb .next_ratio_row

    ; xmm2 := (output value / pivot value)
    movsd xmm2, [rsi + 8*50]
    divsd xmm2, xmm1

    ; if worse ratio, continue
    comisd xmm2, xmm0
    ja .next_ratio_row
    movsd xmm0, xmm2
    mov rdi, rcx

.next_ratio_row:
    add rsi, 8*51
    inc rcx
    jmp .min_ratio_loop

.found_min_ratio:
    ; save pivots on stack
    mov [rsp], rdx
    mov [rsp+8], rdi

    ; xmm1 := pivot value
    mov rax, [rsp+8]
    imul rax, 51*8
    lea rax, [r8 + 2*8 + rax] ; base of row
    movsd xmm1, [rax + 8*rdx]
    ; xmm0 := reciprocal of pivot value
    movsd xmm0, [one]
    divsd xmm0, xmm1

    ; rescale pivot row
    mov rdi, rax
    mov rsi, 51
    call _scale_row

    ; eliminate all rows (including objective)
    ; rcx = current row index we are eliminating
    ; rdi = base pointer to current row
    ; rsi = base pointer to pivot row
    mov rcx, 0
    lea rdi, [r8 + 8*2]
    mov rax, [rsp+8]
    imul rax, 51*8
    lea rsi, [r8 + 2*8 + rax]
.eliminate_rows_loop:
    cmp rcx, 51
    jge .done_eliminating_rows

    ; if row == pivot, continue
    cmp rcx, [rsp+8]
    je .skip_eliminate_row

    mov rdx, 51
    mov rax, [rsp]
    movsd xmm0, [rdi+8*rax]
    movsd xmm1, [neg_one]
    mulsd xmm0, xmm1
    call _eliminate

    sub rsi, 8*51 ; move back base pointer
    jmp .eliminate_next_row
.skip_eliminate_row:
    add rdi, 8*51 ; step over this row
.eliminate_next_row:
    inc rcx
    jmp .eliminate_rows_loop

.done_eliminating_rows:
    ; update corresponding column
    mov rax, [rsp+8]
    lea rax, [r8 + 2 + 50*51 + 51 + 8*rax]
    mov rbx, [rsp]
    mov [rax], rbx
    jmp .main_loop

.done:
    add rsp, 16
    ret

; scale all values in a row by a scalar
; rdi = pointer to row
; rsi = 'length' of the row, in qwords
; xmm0 = scalar by which to multiply
_scale_row:
    test rsi, rsi
    jz .done
.loop:
    movsd xmm1, [rdi]
    mulsd xmm1, xmm0
    movsd [rdi], xmm1

    add rdi, 8
    dec rsi
    jnz .loop
.done:
    ret

; add a scalar multiple of one row to another
; rdi = pointer to 'output' row
; rsi = pointer to 'input' row
; rdx = 'length' of the row, in qwords
; xmm0 = scalar by which to multiply
_eliminate:
    test rdx, rdx
    jz .done
.loop:
    movsd xmm1, [rdi]
    movsd xmm2, [rsi]
    mulsd xmm2, xmm0
    addsd xmm1, xmm2
    movsd [rdi], xmm1

    add rdi, 8
    add rsi, 8
    dec rdx
    jnz .loop
.done:
    ret

section .data
big_m: dq 100.0
epsilon: dq 0.0000001
one: dq 1.0
neg_one: dq -1.0
infty: dq 1000000000000000000.0
neg_infty: dq -1000000000000000000.0

section .bss
; a tableau is stored in memory as 2653 qwords:
; - the first 2 qwords are the `height` and `width` respectively, as u64
; - the next 50*51 qwords represent coefficients of 50 rows of constraints, each with 50 variables.
;       the variables are stored as f64 doubles. The first 50 qwords are the coefficients and the 51st
;       is the 'output'
; - the next 51 qwords represent the coefficients of the objective function (to **maximize**), they
;       are also stored as f64. The first 50 qwords are the coefficients and the 51st
;       is the 'output'
; - the last 50 qwords represent the 'corresponding columns' for each row
tmp_tableau: resq 2 + 50*51 + 51 + 50