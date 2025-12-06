input:
    db "123 328  51 64 ", 0xA
    db " 45 64  387 23 ", 0xA
    db "  6 98  215 314", 0xA
    db "*   +   *   +  ", 0xA

input_bytes equ $ - input
input_lines equ 4
problem_count equ 4