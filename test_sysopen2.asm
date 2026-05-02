; Simulate how compiler opens CPU file - load from global pointer
default rel

%include "config.inc"

section .data
test_path   db "cpu_examples\8bit_example.hdr", 0
cpu_path    dq 0           ; pointer to path, like in main.asm

section .text
global _start
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 80

    ; Set cpu_path to point to test_path, like main.asm does
    lea rax, [rel test_path]
    lea rbx, [rel cpu_path]
    mov [rbx], rax

    ; Now simulate calling parse_cpu_header
    ; Load rdi from cpu_path (like main.asm does)
    lea rbx, [rel cpu_path]
    mov rdi, [rbx]
    
    ; Simulate parse_cpu_header prologue
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; Initialize some variables (like cpuhdr.asm does)
    ; (skip actual global var init, just test sys_open)

    xor rsi, rsi       ; O_RDONLY
    xor rdx, rdx
    sys_open

    test rax, rax
    js .error

    ; Success
    leave
    mov rdi, 0
    sys_exit

.error:
    leave
    mov rdi, 1
    sys_exit
