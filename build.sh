#!/bin/bash
# ============================================
# build.sh - Linux 多模块汇编编译器构建脚本
# ============================================

echo "=========================================="
echo "Building .01 to ASM Compiler (x86_64)"
echo "=========================================="

# 检查 NASM 是否安装
if ! command -v nasm &> /dev/null; then
    echo "Error: NASM not found. Please install NASM."
    echo "  Ubuntu/Debian: sudo apt-get install nasm"
    echo "  CentOS/RHEL:   sudo yum install nasm"
    exit 1
fi

echo "[1/3] Assembling modules..."

# 编译核心模块
nasm -f elf64 main.asm   -o main.o   || exit 1
nasm -f elf64 parse.asm  -o parse.o  || exit 1
nasm -f elf64 table.asm  -o table.o  || exit 1

# 编译指令处理模块
echo "[2/3] Assembling instruction handlers..."
nasm -f elf64 nop.asm   -o nop.o   || exit 1
nasm -f elf64 mov.asm   -o mov.o   || exit 1
nasm -f elf64 add.asm   -o add.o   || exit 1
nasm -f elf64 sub.asm   -o sub.o   || exit 1
nasm -f elf64 mul.asm   -o mul.o   || exit 1
nasm -f elf64 inc.asm   -o inc.o   || exit 1
nasm -f elf64 dec.asm   -o dec.o   || exit 1
nasm -f elf64 xor.asm   -o xor.o   || exit 1
nasm -f elf64 jmp.asm   -o jmp.o   || exit 1
nasm -f elf64 push.asm  -o push.o  || exit 1
nasm -f elf64 pop.asm   -o pop.o   || exit 1

echo "[3/3] Linking..."

# 链接所有目标文件
ld -m elf_x86_64 \
    main.o parse.o table.o \
    nop.o mov.o add.o sub.o mul.o \
    inc.o dec.o xor.o jmp.o push.o pop.o \
    -o compiler

if [ $? -eq 0 ]; then
    echo ""
    echo "Build successful!"
    echo "Usage: ./compiler <input.01>"
    echo "Output: output.asm"
    chmod +x compiler
else
    echo "Linking failed!"
    exit 1
fi
