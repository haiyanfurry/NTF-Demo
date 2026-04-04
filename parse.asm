global parse_line
global token_opcode
global token_op1
global token_op2

extern in_fd

section .bss
line_buf        resb 256
char_buf        resb 1
token_opcode    resb 16
token_op1       resb 16
token_op2       resb 16

section .text
parse_line:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    ; 清空line_buf
    mov rdi, line_buf
    mov rcx, 256
    xor rax, rax
    rep stosb
    
    ; 读取一行
    xor r10, r10
.read_loop:
    mov rax, 0
    mov rdi, [in_fd]
    mov rsi, char_buf
    mov rdx, 1
    syscall
    
    test rax, rax
    jz .eof
    js .eof  ; 处理读取错误
    
    mov al, [char_buf]
    cmp al, 10
    je .line_end
    cmp al, 13
    je .line_end
    
    mov [line_buf + r10], al
    inc r10
    cmp r10, 255
    jl .read_loop

.line_end:
    mov byte [line_buf + r10], 0
    
    ; 保存读取的字符数
    mov rax, r10
    
    ; 分割token
    call split_tokens
    
    leave
    ret

.eof:
    ; 无论是否已经读取了字符，都返回 0
    xor rax, rax
    leave
    ret

split_tokens:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    ; 清空token
    mov rdi, token_opcode
    mov rcx, 16
    xor rax, rax
    rep stosb
    
    mov rdi, token_op1
    mov rcx, 16
    xor rax, rax
    rep stosb
    
    mov rdi, token_op2
    mov rcx, 16
    xor rax, rax
    rep stosb
    
    ; 解析第一个token (指令码)
    mov rsi, line_buf
    mov rdi, token_opcode
    call get_token
    mov rsi, rax
    
    ; 解析第二个token (操作数1)
    mov rdi, token_op1
    call get_token
    mov rsi, rax
    
    ; 解析第三个token (操作数2)
    mov rdi, token_op2
    call get_token
    
    leave
    ret

get_token:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; 检查rdi是否指向有效的内存位置
    cmp rdi, 0
    je .exit
    
    ; 清空目标缓冲区
    mov byte [rdi], 0
    
    ; 检查rsi是否指向有效的内存位置
    cmp rsi, 0
    je .exit
    
    ; 跳过空格
.skip_spaces:
    ; 检查是否遇到结束符
    mov al, [rsi]
    cmp al, 0
    je .exit
    cmp al, 10
    je .exit
    cmp al, 13
    je .exit
    
    ; 检查是否遇到空格
    cmp al, ' '
    je .skip_space
    cmp al, 9
    je .skip_space
    jmp .copy

.skip_space:
    inc rsi
    jmp .skip_spaces
    
    ; 复制token
.copy:
    ; 检查rdi是否指向有效的内存位置
    cmp rdi, 0
    je .exit
    
    ; 写入一个字符
    mov [rdi], al
    inc rdi
    
    ; 检查rsi是否指向有效的内存位置
    cmp rsi, 0
    je .exit
    
    ; 读取下一个字符
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
    
    ; 继续复制
    jmp .copy

.done:
    ; 检查rdi是否指向有效的内存位置
    cmp rdi, 0
    je .exit
    
    ; 添加结束符
    mov byte [rdi], 0

.exit:
    ; 返回更新后的rsi值
    mov rax, rsi
    leave
    ret
