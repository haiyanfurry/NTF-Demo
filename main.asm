global _start
global in_fd
global out_fd
global write_char
global write_output
global flush_output

section .data
in_fd   dq 0
out_fd  dq 1

test_nop db '/home/haiyan/01/test_multiple.01',0
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
    ; 检查命令行参数
    cmp qword [rsp + 8], 2
    jne .use_stdin
    
    ; 打开输入文件
    mov rax, 2
    mov rdi, [rsp + 24]  ; argv[1]
    mov rsi, 0
    mov rdx, 0
    syscall
    test rax, rax
    js .error_open
    mov [in_fd], rax
    
    ; 打开输出文件
    mov rax, 2
    mov rdi, file_output
    mov rsi, 0x401  ; O_CREAT | O_WRONLY | O_TRUNC
    mov rdx, 0644o
    syscall
    test rax, rax
    js .error_open
    mov [out_fd], rax
    jmp .init_buffer

.use_stdin:
    ; 使用标准输入作为输入文件
    mov qword [in_fd], 0
    
    ; 使用标准输出作为输出文件
    mov qword [out_fd], 1

.init_buffer:
    
    ; 初始化输出缓冲区位置
    mov qword [out_pos], 0
    
    ; 循环处理输入，直到遇到EOF
.loop:
    call parse_line
    test rax, rax
    jz .done
    
    ; 查找并执行指令处理函数
    call find_instruction_handler
    jmp .loop
    
.done:
    call flush_output
    
    ; 关闭文件
    mov rax, 3
    mov rdi, [in_fd]
    syscall
    
    mov rax, 3
    mov rdi, [out_fd]
    syscall
    
    ; 退出
    mov rax, 60
    xor rdi, rdi
    syscall

.error_open:
    mov rax, 1
    mov rdi, 2
    mov rsi, error_msg
    mov rdx, error_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

.usage:
    mov rax, 1
    mov rdi, 2
    mov rsi, usage_msg
    mov rdx, usage_len
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

section .data
usage_msg db 'Usage: ./compiler <input.01>',10,0
usage_len equ $ - usage_msg
error_msg db 'Error: Cannot open input file',10,0
error_len equ $ - error_msg

section .text
write_char:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    mov rcx, [out_pos]
    mov [out_buf + rcx], al
    inc rcx
    mov [out_pos], rcx
    cmp rcx, 4095
    jl .done
    call flush_output
.done:
    leave
    ret

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

flush_output:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    mov rax, [out_pos]
    test rax, rax
    jz .done
    mov rax, 1
    mov rdi, [out_fd]
    mov rsi, out_buf
    mov rdx, [out_pos]
    syscall
    mov qword [out_pos], 0
.done:
    leave
    ret
