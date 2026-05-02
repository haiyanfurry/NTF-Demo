; ============================================
; parse.asm - 行解析模块 (跨平台版)
; 功能: 从输入文件读取一行并分割为 token
; ============================================

%include "config.inc"

global parse_line
global token_opcode
global token_op1
global token_op2

extern in_fd

section .bss
line_buf        resb 256
char_buf        resb 1
token_opcode    resb 64
token_op1       resb 64
token_op2       resb 64

section .text
; ============================================
; parse_line: 从输入读取一行并分割 token
; 输出: rax = 读取的字符数 (0 = EOF)
;
; 注意: 使用 r12 作为行内循环计数器
;       因为 sys_read/sys_write 宏会破坏 r10
; ============================================
parse_line:
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 48

    ; 清空 line_buf
    load_addr rdi, line_buf
    mov rcx, 256
    xor rax, rax
    rep stosb

    ; 读取一行
    xor r12, r12
.read_loop:
    ; sys_read(rdi=in_fd, rsi=char_buf, rdx=1)
    load_addr rbx, in_fd
    mov rdi, [rbx]
    load_addr rsi, char_buf
    mov rdx, 1
    sys_read

    test rax, rax
    jz .eof
    js .eof               ; 处理读取错误

    load_addr rbx, char_buf
    mov al, [rbx]
    cmp al, 10
    je .line_end
    cmp al, 13
    je .line_end

    load_addr rbx, line_buf
    mov [rbx + r12], al
    inc r12
    cmp r12, 255
    jl .read_loop

.line_end:
    load_addr rbx, line_buf
    mov byte [rbx + r12], 0

    ; 保存读取的字符数
    mov rax, r12

    ; 分割 token
    call split_tokens

    add rsp, 48
    pop r12
    pop rbp
    ret

.eof:
    ; 返回 0 表示 EOF
    xor rax, rax
    add rsp, 48
    pop r12
    pop rbp
    ret

; ============================================
; split_tokens: 将 line_buf 中的一行分割为三个 token
; ============================================
split_tokens:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    ; 清空 token
    load_addr rdi, token_opcode
    mov rcx, 16
    xor rax, rax
    rep stosb

    load_addr rdi, token_op1
    mov rcx, 16
    xor rax, rax
    rep stosb

    load_addr rdi, token_op2
    mov rcx, 16
    xor rax, rax
    rep stosb

    ; 解析第一个 token (指令码)
    load_addr rsi, line_buf
    load_addr rdi, token_opcode
    call get_token
    mov rsi, rax

    ; 解析第二个 token (操作数1)
    load_addr rdi, token_op1
    call get_token
    mov rsi, rax

    ; 解析第三个 token (操作数2)
    load_addr rdi, token_op2
    call get_token

    leave
    ret

; ============================================
; get_token: 从字符串中提取下一个 token
; 输入: rsi = 源字符串, rdi = 目标缓冲区
; 输出: rax = 更新后的源字符串指针
; ============================================
get_token:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; 检查 rdi 是否有效
    cmp rdi, 0
    je .exit

    ; 清空目标缓冲区
    mov byte [rdi], 0

    ; 检查 rsi 是否有效
    cmp rsi, 0
    je .exit

    ; 跳过空格
.skip_spaces:
    mov al, [rsi]
    cmp al, 0
    je .exit
    cmp al, 10
    je .exit
    cmp al, 13
    je .exit

    cmp al, ' '
    je .skip_space
    cmp al, 9
    je .skip_space
    jmp .copy

.skip_space:
    inc rsi
    jmp .skip_spaces

    ; 复制 token
.copy:
    cmp rdi, 0
    je .exit

    mov [rdi], al
    inc rdi

    cmp rsi, 0
    je .exit

    inc rsi
    mov al, [rsi]

    ; 检查是否遇到空格或结束符
    cmp al, ' '
    je .done
    cmp al, 9
    je .done
    cmp al, 0
    je .done
    cmp al, 10
    je .done
    cmp al, 13
    je .done

    jmp .copy

.done:
    cmp rdi, 0
    je .exit

    mov byte [rdi], 0

.exit:
    mov rax, rsi
    leave
    ret
