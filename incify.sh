#!/usr/bin/env bash
# prepare input for use as a .inc file
# creates input: and input_lines variables

echo "input:"
linecount=0
while IFS= read -r line; do
    echo "    db \"$line\", 0xA"
    ((linecount++))
done

echo ""
echo "input_lines equ $linecount"