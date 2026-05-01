#!/bin/bash
# ============================================
# build.sh - NTF-Demo v2.0 Linux 构建脚本
# ============================================

echo "=========================================="
echo "Building NTF-Demo v2.0 (Linux x86_64)"
echo "=========================================="

# 检查 NASM
if ! command -v nasm &> /dev/null; then
    echo "Error: NASM not found."
    exit 1
fi

# 确保 bin 目录存在
mkdir -p bin

echo "[1/3] Assembling core modules..."

# 编译核心模块
nasm -f elf64 main.asm    -o main.o    || exit 1
nasm -f elf64 cpuhdr.asm  -o cpuhdr.o  || exit 1
nasm -f elf64 input.asm   -o input.o   || exit 1
nasm -f elf64 decode.asm  -o decode.o  || exit 1
nasm -f elf64 codegen.asm -o codegen.o || exit 1

echo "[2/3] Assembling instruction handlers (legacy)..."

# 仍然保留旧指令模块用于兼容
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
nasm -f elf64 print.asm -o print.o || exit 1

echo "[3/3] Linking..."

# 链接 (包含所有模块)
ld -m elf_x86_64 \
    main.o cpuhdr.o input.o decode.o codegen.o \
    nop.o mov.o add.o sub.o mul.o \
    inc.o dec.o xor.o jmp.o push.o pop.o \
    print.o \
    -o bin/compiler

if [ $? -eq 0 ]; then
    cp bin/compiler compiler
    chmod +x bin/compiler compiler
    echo ""
    echo "=========================================="
    echo "Build successful!"
    echo "=========================================="
    echo "Binary: bin/compiler"
    echo ""
    echo "Usage:"
    echo "  ./compiler -c cpu_examples/8bit_example.hdr tests/test_binary.bin"
    echo "  cat output.asm"
    ls -la bin/compiler
else
    echo "Linking failed!"
    exit 1
fi
