; Debug: Test exactly what main.asm does, with path printing
default rel

%include "config.inc"

extern GetCommandLineA
extern parse_cpu_header

section .data
cpu_path        dq 0
input_path      dq 0
output_path     dq 0
input_fmt       dq 0
default_output  db './output.asm', 0
default_cpu     db './cpu.hdr', 0

section .text
global _start

; Helper: print string to stdout (for debug)
print_str:
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
    mov rdi, -11        ; STD_OUTPUT_HANDLE... actually -11
    ; Use get_stdout
    call get_stdout
    mov rdi, rax
    pop rsi
    push rsi
    sys_write
    pop rsi
    leave
    ret

print_crlf:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov rdi, -11
    call get_stdout
    mov rdi, rax
    lea rsi, [rel crlf_str]
    mov rdx, 2
    sys_write
    leave
    ret

section .data
crlf_str    db 13, 10, 0
prefix_cpu  db "cpu_path = ", 0
prefix_in   db "input_path = ", 0
prefix_out  db "output_path = ", 0
prefix_ok   db "parse_cpu_header OK!", 13, 10, 0
prefix_err  db "parse_cpu_header FAILED!", 13, 10, 0

section .text
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 80

    ; Set defaults
    lea rax, [rel default_output]
    lea rbx, [rel output_path]
    mov [rbx], rax

    ; Windows: GetCommandLineA + parse
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
    jle .skip

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
    cmp al, 'o'
    je .opt_o
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

.opt_o:
    cmp r14, r12
    jge .parse_done
    mov rdi, [r13 + r14 * 8]
    inc r14
    lea rbx, [rel output_path]
    mov [rbx], rdi
    jmp .parse_loop

.opt_h:
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
    ; Print cpu_path
    lea rsi, [rel prefix_cpu]
    call print_str
    lea rbx, [rel cpu_path]
    mov rax, [rbx]
    test rax, rax
    jz .no_cpu
    mov rsi, rax
    call print_str
    call print_crlf
    jmp .check_input
.no_cpu:
    lea rsi, [rel default_cpu]
    mov rsi, [rsi]
    call print_str
    call print_crlf

.check_input:
    lea rsi, [rel prefix_in]
    call print_str
    lea rbx, [rel input_path]
    mov rax, [rbx]
    test rax, rax
    jz .no_input
    mov rsi, rax
    call print_str
    call print_crlf
    jmp .do_parse
.no_input:
    lea rsi, [rel crlf_str]
    call print_str

.do_parse:
    ; Now parse CPU header using cpu_path
    lea rbx, [rel cpu_path]
    mov rax, [rbx]
    test rax, rax
    jnz .have_cpu_path
    lea rax, [rel default_cpu]
    mov [rbx], rax
.have_cpu_path:
    mov rdi, [rbx]

    ; Print what we're about to open
    lea rsi, [rel prefix_cpu]
    call print_str
    mov rsi, rdi
    call print_str
    call print_crlf

    call parse_cpu_header
    test rax, rax
    jnz .failed

    lea rsi, [rel prefix_ok]
    call print_str
    xor rdi, rdi
    sys_exit

.failed:
    lea rsi, [rel prefix_err]
    call print_str
    mov rdi, 1
    sys_exit

.skip:
    xor rdi, rdi
    sys_exit

get_stdout:
%ifdef TARGET_WIN64
    sub rsp, 32
    mov rcx, -11
    call GetStdHandle
    add rsp, 32
%else
    mov rax, 1
%endif
    ret

; Copy of parse_cmdline_win from main.asm
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
