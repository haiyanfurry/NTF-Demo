; ============================================
; main.asm - 主入口模块 (跨平台版)
; 支持 Windows (nasm -f win64 -DTARGET_WIN64)
; 支持 Linux   (nasm -f elf64)
; ============================================

%include "config.inc"

global _start
global in_fd
global out_fd
global write_char
global write_output
global flush_output

section .data
in_fd   dq 0
out_fd  dq 0

file_output db './output.asm',0

section .bss
out_buf resb 4096
out_pos resq 1

section .text
extern parse_line
extern find_instruction_handler
extern handle_nop
extern handle_mov

_start:
%ifdef TARGET_WIN64
    ; ========== Windows 入口 ==========
    ; 打开标准输入 (stdin)
    get_stdin
    load_addr rbx, in_fd
    mov [rbx], rax

    ; 创建输出文件 output.asm
    load_addr rdi, file_output
    mov rsi, 0x401         ; O_CREAT | O_WRONLY | O_TRUNC → 映射到 GENERIC_WRITE | CREATE_ALWAYS
    xor rdx, rdx
    sys_open
    test rax, rax
    js .error_open
    load_addr rbx, out_fd
    mov [rbx], rax

    jmp .init_buffer
%else
    ; ========== Linux 入口 ==========
    ; 检查命令行参数
    ; [rsp] = argc, [rsp+8] = argv[0], [rsp+16] = argv[1]
    cmp qword [rsp], 2
    jne .use_stdin

    ; 打开输入文件 (argv[1])
    mov rdi, [rsp + 16]  ; argv[1]
    xor rsi, rsi          ; O_RDONLY
    xor rdx, rdx
    sys_open
    test rax, rax
    js .error_open
    load_addr rbx, in_fd
    mov [rbx], rax

    ; 打开输出文件 output.asm
    load_addr rdi, file_output
    mov rsi, 0x401         ; O_CREAT | O_WRONLY | O_TRUNC
    mov rdx, 0644o
    sys_open
    test rax, rax
    js .error_open
    load_addr rbx, out_fd
    mov [rbx], rax
    jmp .init_buffer

.use_stdin:
    ; 使用标准输入/输出
    load_addr rbx, in_fd
    mov qword [rbx], 0
    load_addr rbx, out_fd
    mov qword [rbx], 1
%endif

.init_buffer:
    load_addr rbx, out_pos
    mov qword [rbx], 0

    ; 循环处理输入，直到遇到EOF
.loop:
    call parse_line
    test rax, rax
    jz .done

    call find_instruction_handler

    jmp .loop

.done:
    call flush_output

    ; 关闭文件
%ifdef TARGET_WIN64
    ; Windows: 关闭文件
    load_addr rbx, in_fd
    mov rdi, [rbx]
    sys_close

    load_addr rbx, out_fd
    mov rdi, [rbx]
    sys_close

    xor rdi, rdi
    sys_exit
%else
    ; Linux: 关闭文件描述符
    load_addr rbx, in_fd
    mov rdi, [rbx]
    sys_close

    load_addr rbx, out_fd
    mov rdi, [rbx]
    sys_close

    xor rdi, rdi
    sys_exit
%endif

.error_open:
%ifndef TARGET_WIN64
    ; Linux: 输出错误信息到 stderr
    load_addr rsi, error_msg
    load_addr rdx, error_len
    ; need actual rdx = error_len, not address
    ; Actually load_addr gives address, but we need value
    ; Let's do it differently
    mov rax, 1
    mov rdi, 2        ; stderr
    load_addr rsi, error_msg
    load_addr rbx, error_len
    mov rdx, [rbx]
    sys_write
    mov rdi, 1
    sys_exit
%else
    ; Windows: 简单退出
    mov rdi, 1
    sys_exit
%endif

; ============================================
; write_char: 写入一个字符到输出缓冲区
; 输入: al = 字符
; ============================================
write_char:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    load_addr rbx, out_pos
    load_addr rcx, out_buf

    mov rdx, [rbx]         ; rdx = out_pos
    mov [rcx + rdx], al    ; out_buf[out_pos] = al
    inc rdx
    mov [rbx], rdx         ; out_pos++

    cmp rdx, 4095
    jl .done
    call flush_output

.done:
    leave
    ret

; ============================================
; write_output: 写入字符串到输出缓冲区
; 输入: rsi = 字符串地址 (以0结尾)
; ============================================
write_output:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    push rsi

.write_loop:
    lodsb
    test al, al
    jz .done
    call write_char
    jmp .write_loop

.done:
    pop rsi
    leave
    ret

; ============================================
; flush_output: 将缓冲区内容写入输出文件
; ============================================
flush_output:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    load_addr rbx, out_pos
    mov rax, [rbx]
    test rax, rax
    jz .done

    ; sys_write(rdi=out_fd, rsi=out_buf, rdx=out_pos)
    load_addr rbx, out_fd
    mov rdi, [rbx]
    load_addr rsi, out_buf
    load_addr rbx, out_pos
    mov rdx, [rbx]
    sys_write

    load_addr rbx, out_pos
    mov qword [rbx], 0

.done:
    leave
    ret

; ============================================
; 静态数据
; ============================================
%ifndef TARGET_WIN64
section .data
usage_msg db 'Usage: ./compiler <input.01>',10,0
usage_len dq $ - usage_msg
error_msg db 'Error: Cannot open input file',10,0
error_len dq $ - error_msg
%endif

