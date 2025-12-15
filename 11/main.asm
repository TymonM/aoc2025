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

; read the graph from input into adjlist
; also calculate indegrees
_init:
    ; clear indegree
    lea rdi, [indegree]
    mov sil, 0
    mov rdx, 26*26*26*8
    call _memset

    ; rdi is input cursor
    ; rsi is adjlist pointer
    ; rcx is remaining lines
    ; rdx is current node
    lea rdi, [input]
    lea rsi, adj
    mov rcx, input_lines

.line_loop:
    push rcx
    push rsi
    call _read_label
    pop rsi
    pop rcx
    
    inc rdi ; skip colon
    mov rdx, rax

    ; set head
    lea r8, [heads]
    lea r8, [r8+8*rdx]
    mov qword [r8], rsi

.edge_loop:
    cmp byte [rdi], 10 ; newline
    je .next_line

    inc rdi ; skip space

    push rcx
    push rsi
    call _read_label
    pop rsi
    pop rcx

    ; label is in rax
    mov qword [rsi], rax
    add rsi, 8 ; advance adjlist pointer

    ; increment indegree
    lea r8, [indegree]
    lea r8, [r8+8*rax]
    inc qword [r8]

    jmp .edge_loop

.next_line:
    inc rdi ; skip newline

    ; set tail
    lea r8, [tails]
    lea r8, [r8+8*rdx]
    mov qword [r8], rsi

    dec rcx
    jnz .line_loop

    ret

_first:
    ; clear dp table
    lea rdi, [dp]
    mov sil, 0
    mov rdx, 26*26*26*8
    call _memset

    ; initialise dp['you'] = 1
    lea rdi, [dp+8*16608]
    mov qword [rdi], 1

    ; stack will contain nodes of indegree 0
    mov rbp, rsp ; so we know when to stop popping later

    ; rcx contains current node we are checking
    mov rcx, 0
.start_indegree_loop:
    cmp rcx, 26*26*26
    jge .dp_loop

    ; check head is valid
    lea rax, [heads]
    mov rax, [rax+8*rcx]
    test rax, rax
    jz .next_node

    ; check indegree
    lea rax, [indegree]
    mov rax, [rax+8*rcx]
    test rax, rax
    jnz .next_node

    ; indegree == 0, so push to stack
    push rcx

.next_node:
    inc rcx
    jmp .start_indegree_loop

.dp_loop:
    cmp rsp, rbp
    jge .done

    pop rax ; rax = curnode
    lea rdi, [heads]
    mov rdi, [rdi+8*rax] ; rdi contains current `to` pointer
    lea rsi, [tails]
    mov rsi, [rsi+8*rax] ; rsi contains `tail` pointer
    lea rcx, [dp]
    mov r8, [rcx+8*rax] ; r8 contains current dp value

.neighbour_iter:
    cmp rdi, rsi
    jge .dp_loop

    mov rax, [rdi]
    ; update push-dp state
    lea rcx, [dp]
    lea rcx, [rcx+8*rax]
    add [rcx], r8

    lea rcx, [indegree]
    lea rcx, [rcx+8*rax] ; rcx = &indegree[to]
    dec qword [rcx]
    jnz .next_neighbour

    push rax ; if (indegree == 0) push(to)

.next_neighbour:
    add rdi, 8 ; next neighbour
    jmp .neighbour_iter

.done:
    ; answer = dp['out']
    ; 14*26*26 + 20*26 + 19
    mov rdi, [dp+10003*8]
    call _write_int

    ret

; read a label "xyz" string into a base-26 integer
; rdi = input cursor (will be advanced by 3 chars)
; returns rax = base-26 integer for read label
_read_label:
    xor rax, rax
    mov rcx, 3 ; remaining chars

.seek_loop:
    imul rax, 26
    movzx rsi, byte [rdi]
    add rax, rsi
    sub rax, 'a'
    inc rdi

    dec rcx
    jnz .seek_loop

    ret

section .data
%include "11/input.inc"

section .bss
adj: resq input_lines*64
heads: resq 26*26*26 ; pointers into adj to first edge
tails: resq 26*26*26 ; pointers into adj to first edge AFTER adjlist for node
dp: resq 26*26*26 ; number of paths to this node
indegree: resq 26*26*26 ; how many more 'dependencies' does this node have
