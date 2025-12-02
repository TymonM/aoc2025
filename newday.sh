#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 DAY" >&2
    exit 1
fi

day=$(printf "%02d" "$1")
file="${day}/main.asm"

if [ -e "$file" ]; then
    echo "Error: $file already exists" >&2
    exit 1
fi

mkdir -p "$day"
cat > "$file" <<'EOF'
; NASM syntax (Intel) for macOS x86_64
default rel

section .text
global _start

_start:
    xor edi, edi
    mov rax, 0x2000001 ; macOS exit syscall (0x2000000 + 1)
    syscall
EOF

echo "Created $file"