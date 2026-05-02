; 最小测试: 直接调用 ExitProcess
default rel

extern ExitProcess

section .text
global _start
_start:
    ; 直接调用 ExitProcess(42)
    sub rsp, 56
    mov rcx, 42
    call ExitProcess
    ; 永远不会到达这里
    add rsp, 56
    ret
