; NASM syntax (Intel) for macOS x86_64

default rel

section .text
global _to_string
global _write_int
global _read_int
global _memcmp
global _sort

; convert rdi to a string
; rdi = integer to convert
; rsi = pointer to output buffer
; returns rax = number of bytes written
_to_string:
    test rdi, rdi
    jz .zero ; special case for 0
    mov r8, 0 ; counter for number of bytes

    push 10 ; so we know when to stop popping

.getdigit:
    xor rdx, rdx
    mov rax, rdi
    mov rcx, 10
    div rcx
    push rdx
    mov rdi, rax
    test rdi, rdi
    jnz .getdigit

.print:
    pop rcx
    cmp rcx, 10
    je .done

    add rcx, '0'
    mov [rsi+1*r8], rcx
    inc r8
    jmp .print
.zero:
    mov [rsi], '0'
    mov rax, 1
    ret
.done:
    mov rax, r8
    ret

; write the integer in rdi to stdout
; followed by a newline
_write_int:
    sub rsp, 32 ; 32 bytes/chars should be enough
    mov rsi, rsp
    call _to_string
    mov rdx, rax ; number of bytes

    ; write the int
    mov rax, 0x2000004
    mov rdi, 1
    ; rsi still holds rsp
    ; rdx has number of bytes
    syscall

    ; write a newline
    mov rax, 0x2000004
    mov rdi, 1
    lea rsi, [.newline]
    mov rdx, 1
    syscall

    add rsp, 32 ; clean up the bytes
    ret

.newline: db 10

; read an integer from a string pointed to by [rdi]
; the integer will go to rax
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

; compare two strings of bytes
; rdi and rsi = pointers to start of the two strings
; rdx = number of bytes to compare
; sets rax = 0 if equal, -1 if rdi string less, 1 if rdi string greater
_memcmp:
    test rdx, rdx
    jz .equal
.loop:
    mov r8b, byte [rdi]
    cmp r8b, byte [rsi]
    jl .less
    jg .greater
    inc rdi
    inc rsi
    dec rdx
    jnz .loop

.equal:
    xor rax, rax ; strings are equal
    ret
.less:
    mov rax, -1
    ret
.greater:
    mov rax, 1
    ret


; quicksort an array of 64-bit integers
; note: always chooses first element as pivot
; rdi = pointer to array
; rsi = number of elements
_sort:
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


