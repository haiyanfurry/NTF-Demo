; Test: GetCommandLineA -> parse_cmdline_win -> parse_cpu_header
default rel

%include "config.inc"

extern GetCommandLineA
extern parse_cpu_header

section .data
cpu_path        dq 0
default_cpu     db "cpu.hdr", 0

section .text
global _start
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 80

    ; Allocate argv array (max 64 args)
    sub rsp, 64 * 8
    mov r15, rsp              ; r15 = argv base
    sub rsp, 32               ; shadow space
    call GetCommandLineA
    add rsp, 32
    mov rdi, rax              ; rdi = command line
    mov rsi, r15              ; rsi = argv buffer
    call parse_cmdline_win
    mov r12, rax              ; r12 = argc
    mov r13, r15              ; r13 = argv

    ; Look for -c option
    xor r14, r14
    inc r14

.scan_loop:
    cmp r14, r12
    jge .check_cpu

    mov rdi, [r13 + r14 * 8]
    inc r14

    mov al, [rdi]
    cmp al, '-'
    jne .scan_loop

    mov al, [rdi + 1]
    cmp al, 'c'
    jne .scan_loop

    ; -c found
    cmp r14, r12
    jge .check_cpu
    mov rdi, [r13 + r14 * 8]
    inc r14
    lea rbx, [rel cpu_path]
    mov [rbx], rdi
    jmp .scan_loop

.check_cpu:
    lea rbx, [rel cpu_path]
    mov rax, [rbx]
    test rax, rax
    jnz .have_cpu

    lea rax, [rel default_cpu]
    mov [rbx], rax

.have_cpu:
    lea rbx, [rel cpu_path]
    mov rdi, [rbx]
    call parse_cpu_header

    test rax, rax
    jnz .error

    xor rdi, rdi
    sys_exit

.error:
    mov rdi, 1
    sys_exit

; Copy of parse_cmdline_win from main.asm
parse_cmdline_win:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi           ; r12 = command line
    mov r13, rsi           ; r13 = argv buffer
    xor r14, r14           ; r14 = argc
    xor r15, r15           ; r15 = current arg start

.skip_spaces:
    mov al, [r12]
    test al, al
    jz .done
    cmp al, ' '
    je .next_char
    cmp al, 9
    je .next_char
    cmp al, 13
    je .next_char
    cmp al, 10
    je .next_char

    mov r15, r12
    cmp al, '"'
    je .quoted

.unquoted:
    inc r12
    mov al, [r12]
    test al, al
    jz .end_unquoted
    cmp al, ' '
    je .end_unquoted
    cmp al, 9
    je .end_unquoted
    cmp al, 13
    je .end_unquoted
    cmp al, 10
    je .end_unquoted
    jmp .unquoted

.end_unquoted:
    mov [r13 + r14 * 8], r15
    inc r14
    cmp al, 0
    je .done
    mov byte [r12], 0
    inc r12
    jmp .skip_spaces

.quoted:
    inc r12
.quoted_loop:
    mov al, [r12]
    test al, al
    jz .end_quoted
    cmp al, '"'
    je .check_esc
    inc r12
    jmp .quoted_loop

.check_esc:
    cmp byte [r12 + 1], '"'
    jne .end_quoted
    add r12, 2
    jmp .quoted_loop

.end_quoted:
    mov [r13 + r14 * 8], r15
    inc r14
    cmp al, 0
    je .done
    mov byte [r12], 0
    inc r12
    jmp .skip_spaces

.next_char:
    inc r12
    jmp .skip_spaces

.done:
    mov qword [r13 + r14 * 8], 0
    mov rax, r14

    pop r15
    pop r14
    pop r13
    pop r12
    leave
    ret
