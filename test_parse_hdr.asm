; Direct test of parse_cpu_header
default rel

%include "config.inc"

extern parse_cpu_header

section .data
test_path   db "cpu.hdr", 0
ok_msg      db "parse_cpu_header OK", 10, 0
fail_msg    db "parse_cpu_header FAILED", 10, 0

section .text
global _start
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 80

    lea rdi, [rel test_path]
    call parse_cpu_header

    test rax, rax
    jnz .error

    mov rdi, 0
    sys_exit

.error:
    mov rdi, 1
    sys_exit
