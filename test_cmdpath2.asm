; Full simulation of main.asm Windows path to parse_cpu_header
default rel

%include "config.inc"

extern GetCommandLineA
extern parse_cpu_header

section .data
in_fd           dq 0
out_fd          dq 0

input_path      dq 0
cpu_path        dq 0
ir_path         dq 0
output_path     dq 0
input_fmt       dq 0

default_output  db './output.asm', 0
default_cpu     db './cpu.hdr', 0

err_open_cpu    db "Error: Cannot open CPU header file.", 10, 0

section .text
global _start
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 80

    ; Set default output path
    lea rax, [rel default_output]
    lea rbx, [rel output_path]
    mov [rbx], rax

    ; Set ir_fd to 0
    lea rbx, [rel ir_path]
    mov qword [rbx], 0

    ; === Windows: GetCommandLineA + parse ===
    sub rsp, 64 * 8
    mov r15, rsp
    sub rsp, 32
    call GetCommandLineA
    add rsp, 32
    mov rdi, rax
    mov rsi, r15
    call parse_cmdline_win
    mov r12, rax              ; argc
    mov r13, r15              ; argv

    cmp r12, 1
    jle .show_help_and_exit

    xor r14, r14
    inc r14

.parse_loop:
    cmp r14, r12
    jge .parse_done

    mov rdi, [r13 + r14 * 8]
    inc r14

    mov al, [rdi]
    cmp al, '-'
    jne .positional

    mov al, [rdi + 1]
    cmp al, 'c'
    je .opt_c
    cmp al, 'h'
    je .opt_h
    cmp al, '-'
    je .opt_long
    jmp .parse_loop

.opt_c:
    cmp r14, r12
    jge .parse_done
    mov rdi, [r13 + r14 * 8]
    inc r14
    lea rbx, [rel cpu_path]
    mov [rbx], rdi
    jmp .parse_loop

.opt_h:
    ; Skip help for now
    jmp .parse_loop

.opt_long:
    mov al, [rdi + 2]
    cmp al, 'c'
    jne .parse_loop
    cmp byte [rdi + 3], 'p'
    jne .parse_loop
    cmp byte [rdi + 4], 'u'
    jne .parse_loop
    cmp r14, r12
    jge .parse_done
    mov rdi, [r13 + r14 * 8]
    inc r14
    lea rbx, [rel cpu_path]
    mov [rbx], rdi
    jmp .parse_loop

.positional:
    lea rbx, [rel input_path]
    mov [rbx], rdi
    jmp .parse_loop

.parse_done:
    lea rbx, [rel cpu_path]
    mov rax, [rbx]
    test rax, rax
    jnz .has_cpu
    lea rax, [rel default_cpu]
    mov [rbx], rax

.has_cpu:
    lea rbx, [rel input_path]
    mov rax, [rbx]
    test rax, rax
    jnz .has_input
    jmp .show_help_and_exit

.has_input:
    lea rbx, [rel cpu_path]
    mov rdi, [rbx]
    call parse_cpu_header
    test rax, rax
    jz .ok

    lea rsi, [rel err_open_cpu]
    call write_stderr
    mov rdi, 1
    sys_exit

.ok:
    xor rdi, rdi
    sys_exit

.show_help_and_exit:
    mov rdi, 1
    sys_exit

; write_stderr - minimal version
write_stderr:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    push rsi
    xor rdx, rdx
.len_loop:
    cmp byte [rsi + rdx], 0
    je .have_len
    inc rdx
    jmp .len_loop
.have_len:
    call get_stderr_fd
    mov rdi, rax
    sys_write
    pop rsi
    leave
    ret

get_stderr_fd:
%ifdef TARGET_WIN64
    push rbp
    mov rbp, rsp
    sub rsp, 48
    mov rcx, STD_ERROR_HANDLE
    call GetStdHandle
    leave
%else
    mov rax, 2
%endif
    ret

; parse_cmdline_win
parse_cmdline_win:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r13, rsi
    xor r14, r14
    xor r15, r15

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
