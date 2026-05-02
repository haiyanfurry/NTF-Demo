; xor.asm - XOR指令处理模块
; 二进制码: 01010
; ============================================

section .text
    global handle_xor
    
    extern write_output, write_char
    extern find_operand_name
    extern token_op1, token_op2
    extern str_xor

handle_xor:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    mov rsi, str_xor
    call write_output
    
    mov al, ' '
    call write_char
    
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
