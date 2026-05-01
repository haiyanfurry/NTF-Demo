#!/bin/bash
# ============================================
# build_windows.sh - NTF-Demo v2.0 Windows 构建脚本
# ============================================

echo "=========================================="
echo "Building NTF-Demo v2.0 (Windows x64)"
echo "=========================================="

# 检查 NASM
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

NASMFLAGS="-f win64 -DTARGET_WIN64"

echo "[1/3] Assembling core modules..."
$NASM $NASMFLAGS main.asm    -o main.o    || exit 1
$NASM $NASMFLAGS cpuhdr.asm  -o cpuhdr.o  || exit 1
$NASM $NASMFLAGS input.asm   -o input.o   || exit 1
$NASM $NASMFLAGS decode.asm  -o decode.o  || exit 1
$NASM $NASMFLAGS codegen.asm -o codegen.o || exit 1

echo "[2/3] Assembling instruction handlers (legacy)..."
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

mkdir -p bin

echo "[3/3] Linking..."
if gcc -m64 -nostdlib -static \
    main.o cpuhdr.o input.o decode.o codegen.o \
    nop.o mov.o add.o sub.o mul.o \
    inc.o dec.o xor.o jmp.o push.o pop.o \
    print.o \
    -o bin/compiler.exe \
    -lkernel32 \
    -Wl,-e,_start \
    -Wl,--subsystem,console; then
    cp bin/compiler.exe compiler.exe
    echo ""
    echo "=========================================="
    echo "Build successful!"
    echo "=========================================="
    echo "Binary: bin/compiler.exe"
    echo ""
    echo "Usage:"
    echo "  compiler.exe -c cpu_examples/8bit_example.hdr tests/test_binary.bin"
    echo "  type output.asm"
    ls -la bin/compiler.exe
else
    echo ""
    echo "gcc linking failed, trying ld directly..."
    ld -e _start \
       --subsystem console \
       main.o cpuhdr.o input.o decode.o codegen.o \
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
