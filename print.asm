; print.asm - PRINT指令处理模块
; 二进制码: 10101
; 功能: 将十六进制编码的字符串转换为汇编 .byte 数据
; 输入格式: 10101 <hex_encoded_string_hex>
; 示例: 10101 48656C6C6F  -> 输出为 db 0x48, 0x65, 0x6C, 0x6C, 0x6F ("Hello")
; ============================================

section .text
    global handle_print

    extern write_output, write_char
    extern token_op1
    extern str_print

handle_print:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; 写入注释行: ; PRINT
    mov al, ';'
    call write_char
    mov al, ' '
    call write_char

    mov rsi, str_print
    call write_output

    mov al, ' '
    call write_char

    ; 从 token_op1 读取十六进制字符串并解码
    mov rsi, token_op1
    call decode_and_emit_hex

    mov al, 10
    call write_char

    leave
    ret

; ============================================
; 解码十六进制字符串并输出为 db 指令
; 输入: rsi = 十六进制字符串地址
; ============================================
decode_and_emit_hex:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    push r12
    push r13
    push r14

    mov r12, rsi        ; 保存原始指针
    xor r13, r13        ; 字节计数

    ; 先输出 "db " 前缀
    mov rsi, .db_prefix
    call write_output

    ; 遍历十六进制字符串，每两个字符转换一个字节
    mov rsi, r12
    xor r13, r13        ; 已输出的字节数

.next_pair:
    ; 读取第一个字符
    lodsb
    cmp al, 0
    je .done
    cmp al, 10
    je .done
    cmp al, 13
    je .done
    cmp al, ' '
    je .done
    
    mov bl, al
    call hex_char_to_val
    shl al, 4
    mov bh, al
    
    ; 读取第二个字符
    lodsb
    cmp al, 0
    je .done
    cmp al, 10
    je .done
    cmp al, 13
    je .done
    cmp al, ' '
    je .done
    
    call hex_char_to_val
    or al, bh
    
    ; 现在 al = 解码后的字节
    ; 先保存字节值到 r14w（write_char 会破坏 bl/rbx）
    mov r14w, ax
    
    ; 检查是否第一个字节，不是则加逗号空格
    test r13, r13
    jz .no_comma
    
    mov al, ','
    call write_char
    mov al, ' '
    call write_char
    
.no_comma:
    ; 输出 "0xNN"
    push rsi
    
    mov al, '0'
    call write_char
    mov al, 'x'
    call write_char
    
    mov ax, r14w        ; 恢复字节值
    shr al, 4
    call val_to_hex_char
    call write_char
    
    mov ax, r14w        ; 重新加载字节值
    and al, 0x0F
    call val_to_hex_char
    call write_char
    
    pop rsi
    inc r13
    jmp .next_pair

.done:
    ; 如果没有任何字节，输出默认值
    test r13, r13
    jnz .exit
    
    mov rsi, .db_default
    call write_output

.exit:
    pop r14
    pop r13
    pop r12
    leave
    ret

.db_prefix db "db ", 0
.db_default db "0x00", 0

; ============================================
; 十六进制字符转数值
; 输入: al = 字符 ('0'-'9', 'A'-'F', 'a'-'f')
; 输出: al = 数值 (0-15)
; ============================================
hex_char_to_val:
    cmp al, '0'
    jb .invalid
    cmp al, '9'
    jbe .digit
    cmp al, 'A'
    jb .invalid
    cmp al, 'F'
    jbe .upper
    cmp al, 'a'
    jb .invalid
    cmp al, 'f'
    jbe .lower
.invalid:
    xor al, al
    ret
.digit:
    sub al, '0'
    ret
.upper:
    sub al, 'A'
    add al, 10
    ret
.lower:
    sub al, 'a'
    add al, 10
    ret

; ============================================
; 数值转十六进制字符
; 输入: al = 数值 (0-15)
; 输出: al = 字符
; ============================================
val_to_hex_char:
    cmp al, 9
    jbe .digit2
    add al, 'A' - 10
    ret
.digit2:
    add al, '0'
    ret
