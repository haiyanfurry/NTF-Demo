; ============================================
; main.asm - NTF-Demo v2.0 主入口 (跨平台版)
; ============================================
; NTF-Demo: 二进制到汇编的通用解码器
;
; 使用:
;   compiler -c cpu.hdr program.bin
;   compiler -c cpu.hdr -x program.hex
; ============================================

default rel

%include "config.inc"

; ============================================
; 导出符号
; ============================================
global _start
global in_fd
global out_fd
global write_char
global write_output
global flush_output

; ============================================
; 外部引用
; ============================================
extern parse_cpu_header
extern open_input
extern close_input
extern input_format
extern INPUT_FMT_BIN
extern INPUT_FMT_HEX
extern INPUT_FMT_TEXT
extern INPUT_FMT_AUTO

extern decode_next_instruction
extern ir_entry_count
extern clear_ir_buffer

extern generate_all
extern GetCommandLineA

; ============================================
; 常量
; ============================================
OUT_BUF_SIZE    equ 4096

; ============================================
; DATA
; ============================================
section .data
in_fd           dq 0
out_fd          dq 0

input_path      dq 0           ; 输入文件路径指针
cpu_path        dq 0           ; CPU 头文件路径指针
ir_path         dq 0           ; IR 输出路径指针 (可选)
output_path     dq 0           ; 输出文件路径指针
input_fmt       dq INPUT_FMT_AUTO  ; 输入格式

; 默认值
default_output  db './output.asm', 0
default_cpu     db './cpu.hdr', 0

; 常量字符串
section .data
help_msg    db "NTF-Demo v2.0 - Binary to Assembly Decoder", 10
            db "Usage: compiler [options] <input>", 10
            db "Options:", 10
            db "  -c, --cpu <file>   CPU definition header", 10
            db "  -b, --binary       Input is raw binary (default)", 10
            db "  -x, --hex          Input is hex text", 10
            db "  -t, --text         Input is legacy .01 text", 10
            db "  -i, --ir <file>    Output IR debug file", 10
            db "  -o, --output <file> Output file (default: output.asm)", 10
            db "  -h, --help         Show this help", 10
            db 0
help_msg_end:

err_no_cpu      db "Error: No CPU header specified.", 10, 0
err_no_input    db "Error: No input file specified.", 10, 0
err_open_cpu    db "Error: Cannot open CPU header file.", 10, 0
err_open_input  db "Error: Cannot open input file.", 10, 0
err_open_output db "Error: Cannot open output file.", 10, 0
err_unknown_opt db "Error: Unknown option: ", 0

section .bss
out_buf         resb OUT_BUF_SIZE
out_pos         resq 1

; IR 文件句柄
ir_fd           resq 1

section .text

; ============================================
; _start: 入口点 (跨平台)
; ============================================
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 80

    ; 初始化
    load_addr rbx, out_pos
    mov qword [rbx], 0

    ; 设置默认输出路径
    load_addr rax, default_output
    load_addr rbx, output_path
    mov [rbx], rax

    ; 设置 IR 文件句柄为 0 (未启用)
    load_addr rbx, ir_fd
    mov qword [rbx], 0

    ; ---- 获取命令行参数 ----
%ifdef TARGET_WIN64
    ; Windows x64: 使用 GetCommandLineA 获取命令行
    ; 在栈上分配 argv 数组 (最大 64 个参数指针)
    sub rsp, 64 * 8           ; 512 字节
    mov r15, rsp              ; 保存 argv 数组基址到 r15
    sub rsp, 32               ; shadow space for GetCommandLineA
    call GetCommandLineA
    add rsp, 32               ; 恢复 shadow space
    mov rdi, rax              ; rdi = 命令行字符串
    mov rsi, r15              ; rsi = argv 缓冲区
    call parse_cmdline_win
    mov r12, rax              ; r12 = argc
    mov r13, r15              ; r13 = argv 数组指针
%else
    ; Linux x86_64: 从堆栈获取 argc/argv
    mov rax, [rbp + 16]       ; argc
    mov r12, rax
    lea r13, [rbp + 24]       ; argv 数组指针
%endif

    cmp r12, 1
    jle .show_help_and_exit

    xor r14, r14              ; argv 索引
    inc r14                   ; 跳过 argv[0] (程序名)

.parse_args_loop:
    cmp r14, r12
    jge .parse_done

    mov rdi, [r13 + r14 * 8]  ; argv[r14]
    inc r14

    ; 检查是否是选项 (以 - 开头)
    mov al, [rdi]
    cmp al, '-'
    jne .is_positional

    ; 处理选项
    mov al, [rdi + 1]
    cmp al, 'c'
    je .opt_c
    cmp al, 'b'
    je .opt_b
    cmp al, 'x'
    je .opt_x
    cmp al, 't'
    je .opt_t
    cmp al, 'i'
    je .opt_i
    cmp al, 'o'
    je .opt_o
    cmp al, 'h'
    je .opt_h
    cmp al, '-'
    je .opt_long
    jmp .unknown_opt

.opt_c:
    ; -c <cpu.hdr>
    cmp r14, r12
    jge .missing_arg
    mov rdi, [r13 + r14 * 8]
    inc r14
    load_addr rbx, cpu_path
    mov [rbx], rdi
    jmp .parse_args_loop

.opt_b:
    ; -b 二进制格式
    load_addr rbx, input_fmt
    mov qword [rbx], INPUT_FMT_BIN
    jmp .parse_args_loop

.opt_x:
    ; -x 十六进制格式
    load_addr rbx, input_fmt
    mov qword [rbx], INPUT_FMT_HEX
    jmp .parse_args_loop

.opt_t:
    ; -t 文本格式
    load_addr rbx, input_fmt
    mov qword [rbx], INPUT_FMT_TEXT
    jmp .parse_args_loop

.opt_i:
    ; -i <ir_file>
    cmp r14, r12
    jge .missing_arg
    mov rdi, [r13 + r14 * 8]
    inc r14
    load_addr rbx, ir_path
    mov [rbx], rdi
    jmp .parse_args_loop

.opt_o:
    ; -o <output.asm>
    cmp r14, r12
    jge .missing_arg
    mov rdi, [r13 + r14 * 8]
    inc r14
    load_addr rbx, output_path
    mov [rbx], rdi
    jmp .parse_args_loop

.opt_h:
    ; -h 帮助
    call show_help
    mov rdi, 0
    sys_exit

.opt_long:
    ; --long options
    mov al, [rdi + 2]
    cmp al, 'c'
    jne .check_help
    cmp byte [rdi + 3], 'p'
    jne .unknown_opt
    cmp byte [rdi + 4], 'u'
    jne .unknown_opt
    ; --cpu
    cmp r14, r12
    jge .missing_arg
    mov rdi, [r13 + r14 * 8]
    inc r14
    load_addr rbx, cpu_path
    mov [rbx], rdi
    jmp .parse_args_loop

.check_help:
    cmp al, 'h'
    jne .unknown_opt
    cmp byte [rdi + 3], 'e'
    jne .unknown_opt
    cmp byte [rdi + 4], 'l'
    jne .unknown_opt
    cmp byte [rdi + 5], 'p'
    jne .unknown_opt
    call show_help
    mov rdi, 0
    sys_exit

.is_positional:
    ; 位置参数 = 输入文件
    load_addr rbx, input_path
    mov [rbx], rdi
    jmp .parse_args_loop

.unknown_opt:
    ; 未知选项
    load_addr rsi, err_unknown_opt
    call write_stderr
    mov rsi, rdi
    call write_stderr
    mov al, 10
    load_addr rsi, stderr_char
    mov [rsi], al
    load_addr rsi, stderr_char
    call write_stderr
    jmp .show_help_and_exit

.missing_arg:
    load_addr rsi, err_no_input
    call write_stderr

.show_help_and_exit:
    call show_help
    mov rdi, 1
    sys_exit

.parse_done:
    ; ---- 验证必要参数 ----
    load_addr rbx, cpu_path
    mov rax, [rbx]
    test rax, rax
    jnz .has_cpu

    ; 尝试默认 cpu.hdr
    load_addr rax, default_cpu
    mov [rbx], rax

.has_cpu:
    load_addr rbx, input_path
    mov rax, [rbx]
    test rax, rax
    jnz .has_input

    load_addr rsi, err_no_input
    call write_stderr
    mov rdi, 1
    sys_exit

.has_input:
    ; ============================================
    ; Step 1: 解析 CPU 头文件
    ; ============================================
    load_addr rbx, cpu_path
    mov rdi, [rbx]
    call parse_cpu_header
    test rax, rax
    jz .cpu_ok

    load_addr rsi, err_open_cpu
    call write_stderr
    mov rdi, 1
    sys_exit

.cpu_ok:
    ; ============================================
    ; Step 2: 打开输出文件
    ; ============================================
%ifdef TARGET_WIN64
    load_addr rbx, output_path
    mov rdi, [rbx]
    mov rsi, 0x401
    xor rdx, rdx
    sys_open
    test rax, rax
    js .error_output
    load_addr rbx, out_fd
    mov [rbx], rax
%else
    load_addr rbx, output_path
    mov rdi, [rbx]
    mov rsi, 0x241         ; O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, 0644o
    sys_open
    test rax, rax
    js .error_output
    load_addr rbx, out_fd
    mov [rbx], rax
%endif

    ; ============================================
    ; Step 3: 打开输入文件
    ; ============================================
    load_addr rbx, input_path
    mov rdi, [rbx]
    load_addr rsi, input_fmt
    mov rsi, [rsi]
    call open_input
    test rax, rax
    jz .input_ok

    load_addr rsi, err_open_input
    call write_stderr
    jmp .error_exit

.input_ok:
    ; ============================================
    ; Step 4: 打开 IR 输出文件 (可选)
    ; ============================================
    load_addr rbx, ir_path
    mov rax, [rbx]
    test rax, rax
    jz .no_ir

%ifdef TARGET_WIN64
    mov rdi, rax
    mov rsi, 0x401
    xor rdx, rdx
    sys_open
    test rax, rax
    js .no_ir
    load_addr rbx, ir_fd
    mov [rbx], rax
%else
    mov rdi, rax
    mov rsi, 0x241
    mov rdx, 0644o
    sys_open
    test rax, rax
    js .no_ir
    load_addr rbx, ir_fd
    mov [rbx], rax
%endif

.no_ir:
    ; ============================================
    ; Step 5: 主解码循环
    ; ============================================
.main_loop:
    call decode_next_instruction
    test rax, rax
    js .main_done
    jmp .main_loop

.main_done:
    ; ============================================
    ; Step 6: 生成汇编输出
    ; ============================================
    call generate_all

    ; ============================================
    ; Step 7: 刷新输出缓冲区
    ; ============================================
    call flush_output

    ; ============================================
    ; Step 8: 输出 IR 调试文件
    ; ============================================
    load_addr rbx, ir_fd
    mov rax, [rbx]
    test rax, rax
    jz .no_ir_output
    call write_ir_file

.no_ir_output:
    ; ============================================
    ; 清理退出
    ; ============================================
    call close_input

    load_addr rbx, out_fd
    mov rdi, [rbx]
    sys_close

    load_addr rbx, ir_fd
    mov rax, [rbx]
    test rax, rax
    jz .exit_ok
    mov rdi, rax
    sys_close

.exit_ok:
    xor rdi, rdi
    sys_exit

.error_output:
    load_addr rsi, err_open_output
    call write_stderr

.error_exit:
    mov rdi, 1
    sys_exit

; ============================================
; get_stderr_fd: 获取标准错误输出句柄/fd
; 输出: rax = stderr 句柄 (Windows) / fd=2 (Linux)
; ============================================
get_stderr_fd:
%ifdef TARGET_WIN64
    push rbp
    mov rbp, rsp
    sub rsp, 48       ; 32 shadow + 16 对齐 (call后 rsp=16K-8, sub 48 → 16K-56, 56mod16=8 → aligned ✓)
    mov rcx, STD_ERROR_HANDLE
    call GetStdHandle
    leave
%else
    mov rax, 2
%endif
    ret

; ============================================
; show_help: 显示帮助信息
; ============================================
show_help:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call get_stderr_fd
    mov rdi, rax
    load_addr rsi, help_msg
    mov rdx, help_msg_end - help_msg
    sys_write

    leave
    ret

; ============================================
; write_stderr: 写入字符串到 stderr
; 输入: rsi = 字符串指针 (0结尾)
; ============================================
write_stderr:
    push rbp
    mov rbp, rsp
    sub rsp, 40          ; 40 + 8(push rbp) + 8(push rsi) = 56 ≡ 8 mod 16 → RSP = 8-56 = -48 ≡ 0 mod 16 ✓

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

; ============================================
; write_ir_file: 将 IR 内容写入调试文件
; (Phase 3 完整实现)
; ============================================
write_ir_file:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    push r12
    push r13

    ; 占位 - Phase 3 实现
    ; 需要遍历 ir_entry_count, 写入格式化的 IR 文本

    pop r13
    pop r12
    leave
    ret

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

    mov rdx, [rbx]
    mov [rcx + rdx], al
    inc rdx
    mov [rbx], rdx

    cmp rdx, OUT_BUF_SIZE - 1
    jl .done
    call flush_output

.done:
    leave
    ret

; ============================================
; write_output: 写入字符串到输出缓冲区
; 输入: rsi = 字符串地址 (0结尾)
; ============================================
write_output:
    push rbp
    mov rbp, rsp
    sub rsp, 56          ; 56 + 8(push rbp) + 8(push rsi) = 72 ≡ 8 mod 16 → RSP = 8-72 = -64 ≡ 0 mod 16 ✓
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
; parse_cmdline_win: 解析 Windows 命令行字符串
; 输入: rdi = 命令行字符串 (GetCommandLineA 返回值)
;       rsi = argv 缓冲区 (存储指针数组)
; 输出: rax = argc (参数个数)
; 破坏: rdi, rsi, rcx, rdx, r8, r9, r10, r11
; ============================================
%ifdef TARGET_WIN64
parse_cmdline_win:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi           ; r12 = 命令行字符串指针
    mov r13, rsi           ; r13 = argv 缓冲区
    xor r14, r14           ; r14 = argc (参数计数)
    xor r15, r15           ; r15 = 当前参数起始位置 (0 = 未开始)

.skip_initial_spaces:
    mov al, [r12]
    test al, al
    jz .done
    cmp al, ' '
    je .next_char_skip
    cmp al, 9              ; tab
    je .next_char_skip
    cmp al, 13             ; CR
    je .next_char_skip
    cmp al, 10             ; LF
    je .next_char_skip

    ; 找到参数起始
    mov r15, r12           ; 记录参数起始
    cmp al, '"'
    je .quoted_arg

.unquoted_arg:
    ; 解析不带引号的参数 (直到空格或结束)
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
    jmp .unquoted_arg

.end_unquoted:
    ; 保存参数指针
    mov [r13 + r14 * 8], r15
    inc r14
    ; 跳过当前字符 (空格分隔符)
    cmp al, 0
    je .done
    inc r12
    jmp .skip_initial_spaces

.quoted_arg:
    ; 解析带引号的参数 (从 r15 开始包含引号)
    inc r12               ; 跳过起始引号
.quoted_loop:
    mov al, [r12]
    test al, al
    jz .end_quoted
    cmp al, '"'
    je .check_escaped_quote
    inc r12
    jmp .quoted_loop

.check_escaped_quote:
    ; 检查是否是转义引号 ""
    cmp byte [r12 + 1], '"'
    jne .end_quoted
    add r12, 2            ; 跳过两个引号
    jmp .quoted_loop

.end_quoted:
    ; 保存参数指针 (包含引号)
    mov [r13 + r14 * 8], r15
    inc r14
    ; 跳过结束引号后的空格
    cmp al, 0
    je .done
    inc r12               ; 跳过结束引号
    jmp .skip_initial_spaces

.next_char_skip:
    inc r12
    jmp .skip_initial_spaces

.done:
    ; 设置 argv[argc] = NULL (标准 argv 终止)
    mov qword [r13 + r14 * 8], 0
    mov rax, r14

    pop r15
    pop r14
    pop r13
    pop r12
    leave
    ret
%endif

; ============================================
; 静态数据
; ============================================
section .data
stderr_char     db 0, 0
