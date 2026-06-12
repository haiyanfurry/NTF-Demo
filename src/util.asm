; ============================================
; util.asm - 共享工具函数 (write_stderr, format_hex_byte)
; ============================================
; 被 main.asm, assembler.asm 等模块共用
; ============================================

default rel

%include "config.inc"

global write_stderr

; ============================================
; BSS
; ============================================
section .bss
util_char_buf   resb 1
util_hex_buf    resb 8

; ============================================
; write_stderr: 写入 null-terminated 字符串到 stderr
; 输入: rsi = 字符串指针
; ============================================
section .text
write_stderr:
    push rbp
    mov rbp, rsp
    sub rsp, 40

    push rsi
    xor rdx, rdx
.len_loop:
    cmp byte [rsi + rdx], 0
    je .have_len
    inc rdx
    jmp .len_loop
.have_len:
    mov rax, 2              ; stderr fd
    mov rdi, rax
    sys_write
    pop rsi

    leave
    ret
