input:
    db "aaa: you hhh", 0xA
    db "you: bbb ccc", 0xA
    db "bbb: ddd eee", 0xA
    db "ccc: ddd eee fff", 0xA
    db "ddd: ggg", 0xA
    db "eee: out", 0xA
    db "fff: out", 0xA
    db "ggg: out", 0xA
    db "hhh: ccc fff iii", 0xA
    db "iii: out", 0xA

input_lines equ 10
