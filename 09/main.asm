; NASM syntax (Intel) for macOS x86_64
default rel

extern _memset
extern _read_int
extern _write_int
extern _compress

section .text
global _start

_start:
    call _init
    call _first
    call _second

    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall

; read in points from input to `points`
_init:
    ; rdi is input cursor, rsi is points cursor
    lea rdi, [input]
    lea rsi, [points]
    mov rcx, input_lines*2 ; num values to read
.read_point_value:
    push rcx
    call _read_int
    mov [rsi], rax
    inc rdi ; skip comma or newline
    add rsi, 8

    pop rcx
    dec rcx
    jnz .read_point_value

    ; copy first point for convenience
    lea rdi, [points]
    mov r8, [rdi]
    mov [rsi], r8
    mov r8, [rdi+8]
    mov [rsi+8], r8

    ret

_first:
    mov qword [output], 0
    ; rdi is current first point pointer
    ; rsi is sentinel
    ; rcx is second point pointer
    lea rdi, points
    lea rsi, points
    add rsi, input_lines*16
.rdi_loop:
    cmp rdi, rsi
    jge .done
    mov rcx, rdi
    add rcx, 16 ; start from next point
.rcx_loop:
    cmp rcx, rsi
    jge .step_rdi_loop

    ; get width, using branchless absolute value
    ; x = (x xor (x >> 63)) - (x >> 63)
    mov rax, [rdi]
    sub rax, [rcx]
    mov r8, rax
    shr r8, 63
    xor rax, r8
    sub rax, r8
    inc rax ; width + 1

    ; get height, similarly
    mov rdx, [rdi+8]
    sub rdx, [rcx+8]
    mov r8, rdx
    shr r8, 63
    xor rdx, r8
    sub rdx, r8
    inc rdx ; height + 1

    imul rax, rdx ; area
    cmp rax, [output]
    jl .step_rcx_loop
    mov qword [output], rax
.step_rcx_loop:
    add rcx, 16 ; 2 qwords per points
    jmp .rcx_loop

.step_rdi_loop:
    add rdi, 16
    jmp .rdi_loop

.done:
    mov rdi, [output]
    call _write_int
    ret

_second:
    call _compress_xy
    call _build_grid
    call _floodfill

    mov qword [output], 0

    ; rcx points to current point, rsi is a sentinel
    lea rcx, [points]
    lea rsi, [points]
    add rsi, input_lines*16 ; 16 bytes per point
.point_loop:
    cmp rcx, rsi
    jge .done

    ; rdx points to second point
    mov rdx, rcx
    add rdx, 16 ; start from next point

.rect_loop:
    cmp rdx, rsi
    jge .next_point

    ; r8 = minx, r9 = maxx
    lea rdi, [compress_x]
    mov r8, [rcx]       ; x1
    mov r8, [rdi+8*r8]  ; compress(x1)
    mov rax, [rdx]   ; x2
    mov rax, [rdi+8*rax] ; compress(x2)
    cmp r8, rax
    cmovg r9, r8
    cmovg r8, rax
    cmovle r9, rax

    ; r10 = miny, r11 = maxy
    lea rdi, [compress_y]
    mov r10, [rcx+8]     ; y1
    mov r10, [rdi+8*r10] ; compress(y1)
    mov rax, [rdx+8]    ; y2
    mov rax, [rdi+8*rax] ; compress(y2)
    cmp r10, rax
    cmovg r11, r10
    cmovg r10, rax
    cmovle r11, rax

    ; check if valid
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    mov rdi, r8
    mov rsi, r9
    mov rdx, r10
    mov rcx, r11
    call _check_rect
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    test rax, rax
    jz .next_rect

    ; calculate area
    ; first get decompressed values
    ; r8 = minx, r9 = maxx
    mov r8, [rcx]    ; x1
    mov rax, [rdx]   ; x2
    cmp r8, rax
    cmovg r9, r8
    cmovg r8, rax
    cmovle r9, rax

    ; r10 = miny, r11 = maxy
    mov r10, [rcx+8]    ; y1
    mov rax, [rdx+8]    ; y2
    cmp r10, rax
    cmovg r11, r10
    cmovg r10, rax
    cmovle r11, rax

    sub r9, r8
    inc r9 ; width+1
    sub r11, r10
    inc r11 ; height+1
    imul r9, r11 ; area is in r9

    cmp r9, [output]
    jl .next_rect
    mov [output], r9
.next_rect:
    add rdx, 16
    jmp .rect_loop


.next_point:
    add rcx, 16
    jmp .point_loop

.done:
    mov rdi, [output]
    call _write_int
    ret

; compress x values into compress_x and y values in compress_y
_compress_xy:
    ; copy x values onto the stack
    mov rcx, 0
    lea rdi, [points]
    sub rsp, 8*input_lines
.copy_x_loop:
    cmp rcx, input_lines
    jge .done_copy_x
    mov r8, [rdi]
    mov [rsp+8*rcx], r8
    add rdi, 16
    inc rcx
    jmp .copy_x_loop
.done_copy_x:

    ; push dummy boundary values
    push 0
    push 99999
    ; compress x values
    mov rdi, rsp
    lea rsi, [compress_x]
    mov rdx, input_lines+2 ; because of dummy values
    call _compress
    add rsp, 16 ; pop dummy values

    ; copy y values into the same stack space
    mov rcx, 0
    lea rdi, [points]
    add rdi, 8 ; offset for y values
    ; we already have stack space so no sub rsp this time
.copy_y_loop:
    cmp rcx, input_lines
    jge .done_copy_y
    mov r8, [rdi]
    mov [rsp+8*rcx], r8
    add rdi, 16
    inc rcx
    jmp .copy_y_loop
.done_copy_y:

    ; push dummy boundary values
    push 0
    push 99999
    ; compress y values
    mov rdi, rsp
    lea rsi, [compress_y]
    mov rdx, input_lines+2
    call _compress

    add rsp, 8*input_lines+16 ; deallocate stack and dummy values

    ret

; initialise `grid` so that byte [compress(y)][compress(x)] is 1 if (x,y) is a vertex or directly
;   between two consecutive vertices, and 0 otherwise
_build_grid:
    ; first fill with 0s
    lea rdi, [grid]
    mov sil, 0
    mov rdx, (input_lines/2)*(input_lines/2)
    call _memset

    ; rdi is points cursor
    ; rcx is remaining points count
    lea rdi, [points]
    mov rcx, input_lines
.points_loop:
    ; r8 = minx, r9 = maxx
    lea rdx, [compress_x]
    mov r8, [rdi]       ; x1
    mov r8, [rdx+8*r8]  ; compress(x1)
    mov rax, [rdi+16]   ; x2
    mov rax, [rdx+8*rax] ; compress(x2)
    cmp r8, rax
    cmovg r9, r8
    cmovg r8, rax
    cmovle r9, rax

    ; r10 = miny, r11 = maxy
    lea rdx, [compress_y]
    mov r10, [rdi+8]     ; y1
    mov r10, [rdx+8*r10] ; compress(y1)
    mov rax, [rdi+24]    ; y2
    mov rax, [rdx+8*rax] ; compress(y2)
    cmp r10, rax
    cmovg r11, r10
    cmovg r10, rax
    cmovle r11, rax

    je .horizontal_edge
.vertical_edge:
    ; r8 contains x, r10 is current y
    cmp r10, r11
    jg .next_edge
    ; set(r8, r10) to 1, first create index
    mov rax, r10
    imul rax, input_lines/2+2
    add rax, r8
    lea rdx, [grid]
    lea rdx, [rdx+rax]
    or byte [rdx], 1

    inc r10
    jmp .vertical_edge
.horizontal_edge:
    ; r10 contains y, r8 is current x
    cmp r8, r9
    jg .next_edge
    ; set (r8,r10) to 1, first create index
    mov rax, r10
    imul rax, input_lines/2+2
    add rax, r8
    lea rdx, [grid]
    lea rdx, [rdx+rax]
    or byte [rdx], 1

    inc r8
    jmp .horizontal_edge
.next_edge:
    add rdi, 16
    dec rcx
    jnz .points_loop

    ret

; set `is_interior` to 1 for compressed coords inside the polygon or on boundary,
;   and 0 for outside
_floodfill:
    ; first fill with ones
    lea rdi, [is_interior]
    mov sil, 1
    mov rdx, (input_lines/2+2)*(input_lines/2+2)
    call _memset

    lea rdi, [grid] ; we will use this as a base for indexing grid
    lea rsi, [is_interior] ; we will use this as a base for indexing the is_interior output

    ; we're gonna perform a dfs on the stack, rbp will tell us when to stop
    ; the dfs will decide which nodes are OUTSIDE the polygon
    mov rbp, rsp
    push 0 ; top left corner is definitely outside polygon, so we start search from there
.dfs:
    cmp rsp, rbp
    je .done

    pop rax
    ; check for oob
    cmp rax, 0
    jl .dfs
    cmp rax, (input_lines/2+2)*(input_lines/2+2)
    jge .dfs

    cmp byte [rsi+rax], 0
    je .dfs ; if (seen) continue
    cmp byte [rdi+rax], 1
    je .dfs ; if (wall) continue

    mov byte [rsi+rax], 0 ; seen = true, i.e. inside_polygon = false

    ; push all neighbours onto the stack
    ; note that we allow wrapping around the edges with a +1 or -1 (which could go to the next row)
    ;   which is sorta weird but actually fine in this case since we know the boundary is all empty anyway
    sub rax, 1
    push rax                         ; left
    add rax, 2
    push rax                         ; right
    sub rax, (input_lines/2+3)
    push rax                         ; down
    add rax, (2*(input_lines/2+2))
    push rax                         ; up
    jmp .dfs

.done:
    ret

; check whether a rectangle is fully contained in the polygon
; rdi = x1 (COMPRESSED)
; rsi = x2
; rdx = y1
; rcx = y2
; requirement: x1<=x2, y1<=y2
; returns rax = 1 if fully cointained and 0 otherwise
_check_rect:
    xor rax, rax ; return 0 by default, in case of early exit

    push rdi ; remember x1 for resetting
    lea r9, [is_interior] ; base pointer for offset indices
.check_row:
    cmp rdx, rcx ; if cury > y2
    jg .success
.check_cell:
    cmp rdi, rsi
    jg .next_row
    
    ; convert to an offset index
    mov r8, rdx
    imul r8, (input_lines/2+2)
    add r8, rdi
    cmp byte [r9+r8], 1 ; check if is_interior[index]
    jne .done

    inc rdi
    jmp .check_cell
.next_row:
    mov rdi, [rsp] ; memorised x1
    inc rdx
    jmp .check_row

.success:
    mov rax, 1 ; we've made it this far so success!
.done:
    pop rdi ; it was for resetting
    ret


section .data
%include "09/input.inc"

section .bss
output: resb 8
points: resq input_lines*2+2 ; 2 qwords per point, and we duplicate first point for convenience
compress_x: resq 100000 ; assuming x values up to 1000000-1
compress_y: resq 100000 ; assuming y values up to 1000000-1
grid: resb (input_lines/2+2)*(input_lines/2+2) ; compressed xs and ys are at most half size, since consecutive vertices share x or y value, but we add 2 extra for dummy columns/rows
is_interior: resb (input_lines/2+2)*(input_lines/2+2)