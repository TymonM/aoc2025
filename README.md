# Executing
Assembling and linking is easy, just run `make xx` where `xx` is the day number. This creates an executable `xx/main`.
This works for my machine, but note, this definitely only works on macOS, and apart from installing `nasm` you might also have to fiddle a bit with the [Makefile](Makefile).

# Input
`input.inc` files are EXCLUDED from the repository as per the [AoC rules](https://adventofcode.com/2025/about#faq_copying). The solutions here don't read from text files, so you have to generate `input.inc` files yourself. You can use the [incify.sh](incify.sh) script to help with that, like so:
```sh
pbpaste | ./incify.sh > 05/input.inc

cat input.txt | ./incify.sh > 05/input.inc
```
or if you want to look fancy:
```sh
./incify.sh <input.txt> 05/input.inc
```

`test.inc` files are included, so you can see those for reference for how the `input.inc` files should be formatted.

## Switching inputs
At the bottom of each `main.asm` is the data section, which includes the `.inc` file with an `%include` macro. Simply change the filepath to use a different input:
```x86asm
section .data
%include "05/input.inc" ; <-- change this line
```