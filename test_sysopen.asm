; Test sys_open macro from config.inc
default rel

%include "config.inc"

section .data
test_path   db "cpu_examples\8bit_example.hdr", 0
ok_msg      db "sys_open OK, handle=", 0
fail_msg    db "sys_open FAILED", 10, 0
crlf        db 10, 0

section .bss
hex_buf     resb 20

section .text
global _start
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 80

    ; Test sys_open with O_RDONLY
    lea rdi, [rel test_path]
    xor rsi, rsi       ; O_RDONLY
    xor rdx, rdx
    sys_open

    test rax, rax
    js .error

    ; Success - print handle (in rax) using ExitProcess code
    ; Just exit with 0 for success
    mov rdi, 0
    sys_exit

.error:
    mov rdi, 1
    sys_exit
