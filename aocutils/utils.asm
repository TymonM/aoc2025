; NASM syntax (Intel) for macOS x86_64

default rel

section .text
global _write_int
global _read_int
global _sort

; write the integer in rdi to stdout
; followed by a newline
_write_int:
    test rdi, rdi
    jz .print_zero ; special case for 0

    mov r8, rdi ; our value to write
    push 10 ; so we know when to stop popping

.getdigit:
    test r8, r8
    jz .print

    xor rdx, rdx
    mov rax, r8
    mov rcx, 10
    div rcx
    push rdx
    mov r8, rax
    jmp .getdigit

.print:
    pop rcx
    cmp rcx, 10
    je .done

    add rcx, '0'
    push rcx ; so that we can get a pointer to it
    ; write the digit
    mov rax, 0x2000004
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1 ; 1 byte to write
    syscall

    pop rcx ; no longer need the char then
    jmp .print

.print_zero:
    mov rax, 0x2000004
    mov rdi, 1
    lea rsi, [.zero]
    mov rdx, 1
    syscall

.done:
    ; write a newline
    mov rax, 0x2000004
    mov rdi, 1
    lea rsi, [.newline]
    mov rdx, 1
    syscall

    ret

.newline: db 10
.zero db '0'

; read an integer from a string pointed to by [rdi]
; the integer will be in rax
; rdi will be advanced to the first char after the integer
_read_int:
    xor rax, rax

.seek_loop:
    movzx rcx, byte [rdi]

    ; check if alphanumeric
    cmp rcx, '0'
    jl .done
    cmp rcx, '9'
    jg .done

    imul rax, 10
    add rax, rcx
    sub rax, '0'
    inc rdi
    jmp .seek_loop

.done:
    ret

_sort:
    ; quicksort an array of 64-bit integers
    ; note: always chooses first element as pivot
    ; rdi = pointer to array
    ; rsi = number of elements
    sub rsp, 8 ; align stack to 16 byte boundary

    cmp rsi, 1
    jle .done

    mov rcx, 1
    mov rdx, 0 ; num elements on the left

.partition:
    cmp rcx, rsi
    jge .recurse

    mov rax, [rdi + rcx * 8]
    cmp rax, [rdi]
    jge .partition_skip

    inc rdx
    ; swap
    mov rax, [rdi + rcx * 8]
    mov r8, [rdi + rdx * 8]
    mov [rdi + rcx * 8], r8
    mov [rdi + rdx * 8], rax

.partition_skip:
    inc rcx
    jmp .partition

.recurse:
    ; swap the pivot into place
    mov rax, [rdi]
    mov r8, [rdi + rdx * 8]
    mov [rdi], r8
    mov [rdi + rdx * 8], rax

    ; rdi already contains what we want
    push rdi
    push rsi
    push rdx
    mov rsi, rdx
    call _sort

    pop rdx
    pop rsi
    pop rdi
    inc rdx
    lea rdi, [rdi + rdx * 8]
    sub rsi, rdx
    call _sort
    ; add rsp, 8
    ; jmp _sort

.done:
    add rsp, 8 ; restore stack alignments
    ret


