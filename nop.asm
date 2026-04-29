section .text
    global handle_nop

    extern write_output, write_char
    extern str_nop

handle_nop:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    mov rsi, str_nop
    call write_output
    
    mov al, 10
    call write_char
    
    leave
    ret
