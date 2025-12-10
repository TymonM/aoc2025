; NASM syntax (Intel) for macOS x86_64

default rel

section .text
global _to_string
global _write_int
global _read_int
global _memcmp
global _memset
global _memsetq
global _sort
global _quickselect
; ---------- DATA STRUCTURES ----------
global _dsu_find
global _dsu_join

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

; set a contiguous block of memory
; rdi = pointer to memory
; rsi = value to set
; rdx = number of bytes
_memset:
    test rdx, rdx
    jz .done
.loop:
    mov byte [rdi], sil
    inc rdi
    dec rdx
    jnz .loop
.done:
    ret

; set a contiguous block of memory, a qword at a time
; rdi = pointer to memory
; rsi = value to set
; rdx = number of qwords
_memsetq:
    test rdx, rdx
    jz .done
.loop:
    mov qword [rdi], rsi
    add rdi, 8
    dec rdx
    jnz .loop
.done:
    ret

; quicksort an array of 64-bit integers
; note: always chooses first element as pivot
; rdi = pointer to array
; rsi = pointer to satellite array
; rdx = number of elements
_sort:
    cmp rdx, 1
    jle .done

    mov rcx, 1
    mov r8, 0 ; num elements on the left

.partition:
    cmp rcx, rdx
    jge .recurse

    mov rax, [rdi + rcx * 8]
    cmp rax, [rdi]
    jge .partition_skip

    inc r8
    ; swap
    mov rax, [rdi + rcx * 8]
    mov r9, [rdi + r8 * 8]
    mov [rdi + rcx * 8], r9
    mov [rdi + r8 * 8], rax
    ; swap satellite
    mov rax, [rsi + rcx * 8]
    mov r9, [rsi + r8 * 8]
    mov [rsi + rcx * 8], r9
    mov [rsi + r8 * 8], rax

.partition_skip:
    inc rcx
    jmp .partition

.recurse:
    ; swap the pivot into place
    mov rax, [rdi]
    mov r9, [rdi + r8 * 8]
    mov [rdi], r9
    mov [rdi + r8 * 8], rax
    ; and in the satellite
    mov rax, [rsi]
    mov r9, [rsi + r8 * 8]
    mov [rsi], r9
    mov [rsi + r8 * 8], rax

    ; rdi already contains what we want
    ; so does rsi
    push rdi
    push rsi
    push rdx
    push r8
    mov rdx, r8
    call _sort

    pop r8
    pop rdx
    pop rsi
    pop rdi
    inc r8
    lea rdi, [rdi + r8 * 8]
    lea rsi, [rsi + r8 * 8]
    sub rdx, r8
    ; call _sort
    jmp _sort ; TRE

.done:
    ret

; quickselect from an array of 64-bit integers in O(n) expected time
; note: always chooses first element as pivot
; rdi = pointer to array
; rsi = pointer to satellite array
; rdx = number of elements
; rcx = index to select (0-based)
; returns nothing, but partitions array so that the first rcx+1 elements
;     are the smallest rcx+1 elements
_quickselect:
    push rcx ; index is now on the stack

    cmp rdx, 1
    jle .done

    mov rcx, 1
    mov r8, 0 ; num elements on the left

.partition:
    cmp rcx, rdx
    jge .recurse

    mov rax, [rdi + rcx * 8]
    cmp rax, [rdi]
    jge .partition_skip

    inc r8
    ; swap
    mov rax, [rdi + rcx * 8]
    mov r9, [rdi + r8 * 8]
    mov [rdi + rcx * 8], r9
    mov [rdi + r8 * 8], rax
    ; swap satellite
    mov rax, [rsi + rcx * 8]
    mov r9, [rsi + r8 * 8]
    mov [rsi + rcx * 8], r9
    mov [rsi + r8 * 8], rax

.partition_skip:
    inc rcx
    jmp .partition

.recurse:
    ; swap the pivot into place
    mov rax, [rdi]
    mov r9, [rdi + r8 * 8]
    mov [rdi], r9
    mov [rdi + r8 * 8], rax
    ; and in the satellite
    mov rax, [rsi]
    mov r9, [rsi + r8 * 8]
    mov [rsi], r9
    mov [rsi + r8 * 8], rax

    ; if r8 == index, done
    cmp r8, [rsp]
    je .done

    ; if r8 > index, recurse left
    jg .recurse_left
.recurse_right:
    pop rcx
    inc r8
    sub rcx, r8
    lea rdi, [rdi + r8 * 8]
    lea rsi, [rsi + r8 * 8]
    sub rdx, r8
    jmp _quickselect
.recurse_left:
    pop rcx
    mov rdx, r8
    jmp _quickselect

.done:
    pop rcx ; stored index

    ret

; ---------- DATA STRUCTURES ----------
; returns root of DSU component (applying path compression), in which -1 represents 'no parent'
; rdi = pointer to dsu.parent array
; rsi = query
; returns rax = root of component
_dsu_find:
    mov r8, [rdi+8*rsi] ; r8 contains the parent
    cmp r8, -1
    je .already_root

    ; p[x] = find(p[x])
    push rsi
    mov rsi, r8
    call _dsu_find
    pop rsi
    mov [rdi+8*rsi], rax
    ; rax contains the root from recursive call so ret
    ret
.already_root:
    mov rax, rsi
    ret

; joins two nodes in the DSU, maintaining component sizes (but NOT merging by size)
; rdi = pointer to dsu.parent array
; rsi = pointer to dsu.size array
; rdx = index a to join
; rcx = index b to join
; returns rax = 1 if a new join occured, or 0 if they were already in the same component
_dsu_join:
    ; a = find(a)
    push rsi
    mov rsi, rdx ; query = a
    call _dsu_find
    pop rsi
    mov rdx, rax ; a = find(a)

    ; b = find(b) similarly
    push rsi
    mov rsi, rcx
    call _dsu_find
    pop rsi
    mov rcx, rax

    ; if a == b return 0
    xor rax, rax
    cmp rdx, rcx
    je .done

    ; p[a] = b
    lea rdi, [rdi+8*rdx]
    mov [rdi], rcx

    ; size[b] += size[a]
    mov rdi, [rsi+8*rdx] ; rdi = size[a]
    lea rsi, [rsi+8*rcx] ; rsi = &size[b]
    add [rsi], rdi

    mov rax, 1
.done:
    ret
