; 测试堆栈对齐
default rel

extern ExitProcess

section .text
global _start

; 测试不同对齐方式
; Windows x64 要求: call 时 RSP 必须 16 字节对齐

_start:
    push rbp
    mov rbp, rsp
    sub rsp, 80          ; 80 = 16*5, 所以 RSP = entry-88
                         ; entry RSP 是 16 字节对齐的
                         ; 88 mod 16 = 8, 所以 RSP = 8 mod 16
    
    ; ExitProcess 需要 RSP = ? mod 16 在 call 时
    sub rsp, 56          ; 56 mod 16 = 8
                         ; RSP = (8-8) mod 16 = 0 mod 16 在 call 时
    mov rcx, 0
    call ExitProcess
    add rsp, 56
