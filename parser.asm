; ============================================
; parser.asm - 行解析器模块
; 功能：读取文件行、分割token、查找操作数
; ============================================

section .data
    ; 全局变量
    global line_buf, line_len
    global tok1, tok2, tok3
    global in_fd, out_fd
    global out_buf, out_len
    
    ; 行缓冲区
    line_buf    times 256 db 0
    line_len    dd 0
    
    ; token缓冲区
    tok1        times 16 db 0
    tok2        times 16 db 0
    tok3        times 16 db 0
    
    ; 输出缓冲区
    out_buf     times 256 db 0
    out_len     dd 0
    
    ; 文件描述符
    in_fd       dd 0
    out_fd      dd 0

section .bss
    char_buf    resb 1

; ============================================
; 代码段
; ============================================
section .text
    ; 导出函数
    global read_line
    global parse_tokens
    global find_operand
    global write_str
    global write_char
    global flush_output
    
    ; 导入外部符号
    extern op_tab, OP_COUNT, OP_SIZE
    extern SYS_READ, SYS_WRITE

; ============================================
; read_line - 从输入文件读取一行
; 输入: 无 (使用全局in_fd)
; 输出: eax = 行长度, 0=EOF
; ============================================
read_line:
    push ebx
    push ecx
    push edx
    push esi
    
    mov esi, line_buf
    xor ecx, ecx
    
.read_char:
    ; 读取一个字符
    mov eax, SYS_READ
    mov ebx, [in_fd]
    push ecx
    push esi
    mov ecx, char_buf
    mov edx, 1
    int 0x80
    pop esi
    pop ecx
    
    cmp eax, 0
    jle .eof
    
    mov al, [char_buf]
    
    ; 检查换行
    cmp al, 10
    je .line_end
    cmp al, 13
    je .line_end
    
    ; 存储字符
    mov [esi + ecx], al
    inc ecx
    cmp ecx, 255
    jl .read_char
    
.line_end:
    mov byte [esi + ecx], 0
    mov [line_len], ecx
    mov eax, ecx
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
    
.eof:
    cmp ecx, 0
    je .empty_line
    jmp .line_end
    
.empty_line:
    xor eax, eax
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================
; parse_tokens - 将line_buf分解为tok1, tok2, tok3
; 输入: 无 (使用全局line_buf)
; 输出: 无 (结果存入tok1, tok2, tok3)
; ============================================
parse_tokens:
    pusha
    
    ; 清空token
    mov edi, tok1
    mov ecx, 16
    xor eax, eax
    rep stosb
    mov edi, tok2
    mov ecx, 16
    rep stosb
    mov edi, tok3
    mov ecx, 16
    rep stosb
    
    mov esi, line_buf
    mov edi, tok1
    call get_token
    mov edi, tok2
    call get_token
    mov edi, tok3
    call get_token
    
    popa
    ret

; ============================================
; get_token - 从ESI获取一个token到EDI
; 输入: ESI=源地址, EDI=目标地址
; 输出: ESI=下一个位置, EDI填充token
; ============================================
get_token:
    ; 跳过空格
.skip:
    lodsb
    cmp al, ' '
    je .skip
    cmp al, 9           ; tab
    je .skip
    cmp al, 0
    je .empty
    
    ; 复制token
.copy:
    stosb
    lodsb
    cmp al, ' '
    je .end
    cmp al, 0
    je .end
    cmp al, 9
    je .end
    jmp .copy
    
.end:
    dec esi
    mov byte [edi], 0
    ret
    
.empty:
    dec esi
    mov byte [edi], 0
    ret

; ============================================
; find_operand - 查找操作数对应的名称
; 输入: ESI=token地址 (如tok2或tok3)
; 输出: eax=操作数名地址, 0=未找到
; ============================================
find_operand:
    push ebx
    push ecx
    push edx
    push edi
    
    mov ebx, op_tab
    mov ecx, OP_COUNT
    
.loop:
    push ecx
    mov edi, ebx          ; 表项地址
    mov ecx, 10           ; 比较10字节 ("00x00000\0")
    repe cmpsb
    pop ecx
    je .found
    
    add ebx, OP_SIZE      ; 下一个表项
    loop .loop
    
    xor eax, eax          ; 未找到
    jmp .exit
    
.found:
    mov eax, [ebx + 10]   ; 获取名称地址
    
.exit:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================
; write_str - 写入字符串到输出缓冲区
; 输入: ESI=字符串地址
; 输出: 无
; ============================================
write_str:
    pusha
    
.loop:
    lodsb
    cmp al, 0
    je .exit
    call write_char
    jmp .loop
    
.exit:
    popa
    ret

; ============================================
; write_char - 写入单个字符到输出缓冲区
; 输入: al=字符
; 输出: 无
; ============================================
write_char:
    push ebx
    push ecx
    push edx
    push eax
    
    mov ecx, [out_len]
    mov [out_buf + ecx], al
    inc ecx
    mov [out_len], ecx
    
    pop eax
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================
; flush_output - 刷新输出缓冲区到文件
; 输入: 无 (使用全局out_fd, out_buf, out_len)
; 输出: 无
; ============================================
flush_output:
    pusha
    
    mov eax, SYS_WRITE
    mov ebx, [out_fd]
    mov ecx, out_buf
    mov edx, [out_len]
    int 0x80
    
    mov dword [out_len], 0
    
    popa
    ret
