; This file contains functions for Integer Linear Programming
; Why is this not in `utils.asm`? Because it is hugeeee and sort of a separate project at this point

; NASM syntax (Intel) for macOS x86_64

default rel

section .text
global _add_doubles

; add two 64-bit floating point numbers
; rdi = pointer to first double
; rsi = pointer to second double
; rdx = pointer to output double
_add_doubles:
    movsd xmm0, qword [rdi]
    addsd xmm0, qword [rsi]
    movsd qword [rdx], xmm0
    ret