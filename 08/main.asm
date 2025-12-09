; NASM syntax (Intel) for macOS x86_64
default rel

extern _memset
extern _memsetq
extern _write_int
extern _dsu_find
extern _dsu_join

section .text
global _start

_start:
    ; clear parents
    lea rdi, [parent]
    mov rsi, 0xFF ; -1
    mov rdx, 64
    call _memset

    ; clear sizes
    lea rdi, [size]
    mov rsi, 1
    mov rdx, 64
    call _memsetq

    ; do some joins
    lea rdi, [parent]
    lea rsi, [size]
    mov rdx, 0
    mov rcx, 1
    call _dsu_join

    lea rdi, [parent]
    lea rsi, [size]
    mov rdx, 3
    mov rcx, 4
    call _dsu_join

    lea rdi, [parent]
    lea rsi, [size]
    mov rdx, 0
    mov rcx, 4
    call _dsu_join

    lea rdi, [parent]
    lea rsi, [size]
    mov rdx, 2
    mov rcx, 6
    call _dsu_join

    lea rdi, [parent]
    lea rsi, [size]
    mov rdx, 6
    mov rcx, 7
    call _dsu_join
    
    mov rcx, 0
.print_loop:
    cmp rcx, 8
    jge .print_sizes
    lea rdi, [parent]
    mov rsi, rcx
    call _dsu_find
    mov rdi, rax
    push rcx
    push rsi
    call _write_int
    pop rsi
    pop rcx
    inc rcx
    jmp .print_loop

.print_sizes:
    ; write a newline
    mov rax, 0x2000004
    mov rdi, 1
    push 10 ; newline
    mov rsi, rsp
    mov rdx, 1
    syscall
    pop rax

    mov rcx, 0
.size_loop:
    cmp rcx, 8
    jge .done
    lea rdi, [parent]
    lea rdi, [rdi + 8*rcx]
    cmp [rdi], -1
    jne .step_size_loop ; we only want to print sizes for the roots
    push rcx
    lea rdi, [size]
    mov rdi, [rdi + 8*rcx]
    call _write_int
    pop rcx
.step_size_loop:
    inc rcx
    jmp .size_loop
.done:

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

section .bss
parent: resq 8
size: resq 8