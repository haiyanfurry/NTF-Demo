#!/bin/bash
echo "=== GLOBAL declarations ==="
for f in *.asm; do
    echo "=== $f ==="
    grep -n "^\s*global" "$f" 2>/dev/null || echo "  (none)"
done
echo ""
echo "=== EXTERN declarations ==="
for f in *.asm; do
    echo "=== $f ==="
    grep -n "^\s*extern" "$f" 2>/dev/null || echo "  (none)"
done
