#!/bin/bash
# ============================================
# build_windows.sh - Windows (MSYS2/Cygwin) 构建脚本
# 使用: ./build_windows.sh
# 编译方式: nasm -f win64 -DTARGET_WIN64
# ============================================

echo "=========================================="
echo "Building .01 to ASM Compiler (Windows x64)"
echo "=========================================="

# 检查 NASM 是否安装
NASM="nasm"
if ! command -v nasm &> /dev/null; then
    for p in /usr/bin/nasm /usr/local/bin/nasm D:/mys32/usr/bin/nasm.exe; do
        if [ -f "$p" ]; then
            NASM="$p"
            echo "Found NASM at: $NASM"
            break
        fi
    done
    if [ "$NASM" = "nasm" ]; then
        echo "Error: NASM not found."
        exit 1
    fi
fi

# NASM flags for Windows x64
# -DTARGET_WIN64 : 启用 Windows 代码路径 (通过 config.inc)
# 注意: 不使用 --prefix _ ! 因为 x64 Windows API 不添加下划线
NASMFLAGS="-f win64 -DTARGET_WIN64"

echo "[1/3] Assembling core modules..."
$NASM $NASMFLAGS main.asm   -o main.o   || exit 1
$NASM $NASMFLAGS parse.asm  -o parse.o  || exit 1
$NASM $NASMFLAGS table.asm  -o table.o  || exit 1

echo "[2/3] Assembling instruction handlers..."
$NASM $NASMFLAGS nop.asm   -o nop.o   || exit 1
$NASM $NASMFLAGS mov.asm   -o mov.o   || exit 1
$NASM $NASMFLAGS add.asm   -o add.o   || exit 1
$NASM $NASMFLAGS sub.asm   -o sub.o   || exit 1
$NASM $NASMFLAGS mul.asm   -o mul.o   || exit 1
$NASM $NASMFLAGS inc.asm   -o inc.o   || exit 1
$NASM $NASMFLAGS dec.asm   -o dec.o   || exit 1
$NASM $NASMFLAGS xor.asm   -o xor.o   || exit 1
$NASM $NASMFLAGS jmp.asm   -o jmp.o   || exit 1
$NASM $NASMFLAGS push.asm  -o push.o  || exit 1
$NASM $NASMFLAGS pop.asm   -o pop.o   || exit 1
$NASM $NASMFLAGS print.asm -o print.o || exit 1

# 确保 bin 目录存在
mkdir -p bin

echo "[3/3] Linking..."
# 尝试使用 gcc 链接 (需要 -lkernel32 提供 Windows API)
# --prefix _ 已移除，x64 Windows API 使用无修饰符号名
if gcc -m64 -nostdlib -static \
    main.o parse.o table.o \
    nop.o mov.o add.o sub.o mul.o \
    inc.o dec.o xor.o jmp.o push.o pop.o \
    print.o \
    -o bin/compiler.exe \
    -lkernel32 \
    -Wl,-e,_start \
    -Wl,--subsystem,console; then
    # 同时复制到根目录方便使用
    cp bin/compiler.exe compiler.exe
    echo ""
    echo "=========================================="
    echo "Build successful!"
    echo "=========================================="
    echo "Binary: bin/compiler.exe"
    echo ""
    echo "Quick usage:"
    echo "  cd bin"
    echo "  type ..\tests\test_nop.01 | compiler.exe"
    echo "  type output.asm"
    echo ""
    echo "Or from project root:"
    echo "  type tests\test_nop.01 | compiler.exe"
    echo "Output: output.asm"
    ls -la bin/compiler.exe
else
    echo ""
    echo "gcc linking failed, trying ld directly..."
    # 备用方案: 直接使用 ld 链接
    ld -e _start \
       --subsystem console \
       main.o parse.o table.o \
       nop.o mov.o add.o sub.o mul.o \
       inc.o dec.o xor.o jmp.o push.o pop.o \
       print.o \
       -o bin/compiler.exe \
       -lkernel32 && \
    cp bin/compiler.exe compiler.exe && \
    echo "Build successful with ld!" && \
    ls -la bin/compiler.exe || \
    echo "Linking failed!"
fi
