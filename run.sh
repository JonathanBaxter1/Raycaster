#!/bin/sh

nasm -f bin boot.asm -o boot.bin
nasm -f bin main.asm -o main.bin
cat boot.bin main.bin > raycaster.bin
qemu-system-x86_64 -hda raycaster.bin
