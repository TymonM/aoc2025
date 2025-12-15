input:
    db "svr: aaa bbb", 0xA
    db "aaa: fft", 0xA
    db "fft: ccc", 0xA
    db "bbb: tty", 0xA
    db "tty: ccc", 0xA
    db "ccc: ddd eee", 0xA
    db "ddd: hub", 0xA
    db "hub: fff", 0xA
    db "eee: dac", 0xA
    db "dac: fff", 0xA
    db "fff: ggg hhh", 0xA
    db "ggg: out", 0xA
    db "hhh: out", 0xA

input_lines equ 13
