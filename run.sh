#!/bin/bash
# ============================================
# run.sh - 快速运行编译器
# 用法: ./run.sh [test_file]
# 默认: tests/test_nop.01
# ============================================

TEST_FILE="${1:-tests/test_nop.01}"

if [ ! -f "$TEST_FILE" ]; then
    echo "Error: Test file not found: $TEST_FILE"
    exit 1
fi

echo "Compiling: $TEST_FILE"
cat "$TEST_FILE" | ./bin/compiler
echo ""
echo "Output: output.asm"
