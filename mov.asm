; mov.asm - MOV指令处理模块
; 二进制码: 00001
; 功能: 传送数据
; 格式: mov 目标, 源
; ============================================

section .text
    global handle_mov
    
    extern write_output, write_char
    extern find_operand_name
    extern token_op1, token_op2
    extern str_mov

handle_mov:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    mov rsi, str_mov
    call write_output
    
    mov al, ' '
    call write_char
    ; 操作数1
    mov rsi, token_op1
    call find_operand_name
    test rax, rax
    jz .error
    mov rsi, rax
    call write_output
    
    mov al, ','
    call write_char
    mov al, ' '
    call write_char
    ; 操作数2
    mov rsi, token_op2
    call find_operand_name
    test rax, rax
    jz .error
    mov rsi, rax
    call write_output
    
    mov al, 10
    call write_char
    
    leave
    ret

.error:
    leave
    ret
