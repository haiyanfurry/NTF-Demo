; ============================================
; 自定义汇编编译器 (NASM 32位)
; 将二进制+00x魔数格式编译成标准x86汇编
; ============================================

section .data
    ; 文件名
    input_file  db "input.txt", 0
    output_file db "output.asm", 0
    
    ; 系统调用号 (Linux 32位)
    SYS_READ    equ 3
    SYS_WRITE   equ 4
    SYS_OPEN    equ 5
    SYS_CLOSE   equ 6
    SYS_EXIT    equ 1
    
    ; 文件打开模式
    O_RDONLY    equ 0
    O_WRONLY    equ 1
    O_CREAT     equ 64
    O_TRUNC     equ 512
    MODE        equ 0644o
    
    ; 文件描述符
    in_fd       dd 0
    out_fd      dd 0
    
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

; ============================================
; 指令映射表 (5位二进制 -> 指令名)
; ============================================
section .data
    ; 指令名称字符串
    str_nop     db "nop", 0
    str_mov     db "mov", 0
    str_add     db "add", 0
    str_sub     db "sub", 0
    str_mul     db "mul", 0
    str_inc     db "inc", 0
    str_dec     db "dec", 0
    str_xor     db "xor", 0
    str_jmp     db "jmp", 0
    str_push    db "push", 0
    str_pop     db "pop", 0
    
    ; 指令查找表: 二进制码(6字节) + 指令名地址(4字节)
    inst_tab:
        db "00000", 0
        dd str_nop
        db "00001", 0
        dd str_mov
        db "00010", 0
        dd str_add
        db "00011", 0
        dd str_sub
        db "00100", 0
        dd str_mul
        db "00110", 0
        dd str_inc
        db "00111", 0
        dd str_dec
        db "01010", 0
        dd str_xor
        db "01101", 0
        dd str_jmp
        db "10011", 0
        dd str_push
        db "10100", 0
        dd str_pop
    INST_COUNT equ 11
    INST_SIZE  equ 10       ; 6字节字符串 + 4字节地址

; ============================================
; 操作数映射表 (00x000xx -> 名称)
; ============================================
section .data
    ; 寄存器/立即数字符串
    str_ax      db "ax", 0
    str_bx      db "bx", 0
    str_cx      db "cx", 0
    str_dx      db "dx", 0
    str_0       db "0", 0
    str_1       db "1", 0
    str_2       db "2", 0
    str_3       db "3", 0
    str_5       db "5", 0
    str_10      db "10", 0
    str_99      db "99", 0
    
    ; 操作数查找表: 魔数(10字节) + 名称地址(4字节)
    op_tab:
        db "00x00000", 0
        dd str_0
        db "00x00001", 0
        dd str_ax
        db "00x00002", 0
        dd str_bx
        db "00x00003", 0
        dd str_cx
        db "00x00004", 0
        dd str_dx
        db "00x00017", 0
        dd str_1
        db "00x00018", 0
        dd str_2
        db "00x00019", 0
        dd str_3
        db "00x00021", 0
        dd str_5
        db "00x00023", 0
        dd str_10
        db "00x00027", 0
        dd str_99
    OP_COUNT equ 12
    OP_SIZE  equ 14         ; 10字节字符串 + 4字节地址

; ============================================
; 操作数个数表
; ============================================
section .data
    opcnt_tab:
        db 0        ; nop: 0
        db 2        ; mov: 2
        db 2        ; add: 2
        db 2        ; sub: 2
        db 2        ; mul: 2
        db 0        ; (保留)
        db 1        ; inc: 1
        db 1        ; dec: 1
        db 0        ; (保留)
        db 0        ; (保留)
        db 2        ; xor: 2
        db 0        ; (保留)
        db 0        ; (保留)
        db 1        ; jmp: 1
        db 0        ; (保留)
        db 0        ; (保留)
        db 0        ; (保留)
        db 0        ; (保留)
        db 0        ; (保留)
        db 1        ; push: 1
        db 1        ; pop: 1

; ============================================
; BSS段
; ============================================
section .bss
    char_buf    resb 1

; ============================================
; 代码段
; ============================================
section .text

_start:
    ; 打开输入文件
    mov eax, SYS_OPEN
    mov ebx, input_file
    mov ecx, O_RDONLY
    xor edx, edx
    int 0x80
    
    test eax, eax
    js .exit_error
    mov [in_fd], eax
    
    ; 打开输出文件
    mov eax, SYS_OPEN
    mov ebx, output_file
    mov ecx, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, MODE
    int 0x80
    
    test eax, eax
    js .exit_error
    mov [out_fd], eax
    
    ; 主循环
.loop:
    call read_line
    cmp eax, 0
    jle .done
    
    call parse_tokens
    call generate_asm
    jmp .loop
    
.done:
    ; 关闭文件
    mov eax, SYS_CLOSE
    mov ebx, [in_fd]
    int 0x80
    
    mov eax, SYS_CLOSE
    mov ebx, [out_fd]
    int 0x80
    
    ; 退出
    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80
    
.exit_error:
    mov eax, SYS_EXIT
    mov ebx, 1
    int 0x80

; ============================================
; 读取一行到line_buf
; 返回: eax = 行长度, 0=EOF
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
; 解析token: 将line_buf分解为tok1, tok2, tok3
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
; 从ESI获取一个token到EDI
; ============================================
get_token:
    ; 跳过空格
.skip:
    lodsb
    cmp al, ' '
    je .skip
    cmp al, 9
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
; 查找指令: 输入tok1, 输出eax=指令名地址
; ============================================
find_inst:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov ebx, inst_tab
    mov ecx, INST_COUNT
    
.loop:
    push ecx
    mov esi, tok1
    mov edi, ebx
    mov ecx, 6
    repe cmpsb
    pop ecx
    je .found
    
    add ebx, INST_SIZE
    loop .loop
    
    xor eax, eax
    jmp .exit
    
.found:
    mov eax, [ebx + 6]
    
.exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================
; 查找操作数: 输入esi=token地址, 输出eax=操作数名地址
; ============================================
find_op:
    push ebx
    push ecx
    push edx
    push edi
    
    mov ebx, op_tab
    mov ecx, OP_COUNT
    
.loop:
    push ecx
    mov edi, ebx
    mov ecx, 10
    repe cmpsb
    pop ecx
    je .found
    
    add ebx, OP_SIZE
    loop .loop
    
    xor eax, eax
    jmp .exit
    
.found:
    mov eax, [ebx + 10]
    
.exit:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================
; 获取指令操作数个数
; 输入: tok1包含二进制码
; 输出: eax=操作数个数
; ============================================
get_opcnt:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; 将二进制字符串转为数字
    mov esi, tok1
    xor eax, eax
    xor ebx, ebx
    
.convert:
    lodsb
    cmp al, 0
    je .done
    sub al, '0'
    shl ebx, 1
    or bl, al
    jmp .convert
    
.done:
    ; 查表获取操作数个数
    movzx eax, byte [opcnt_tab + ebx]
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================
; 生成汇编输出
; ============================================
generate_asm:
    pusha
    
    mov dword [out_len], 0
    
    ; 查找指令
    call find_inst
    test eax, eax
    jz .error
    
    ; 写入指令名
    mov esi, eax
    call write_str
    
    ; 获取操作数个数
    call get_opcnt
    cmp eax, 0
    je .newline
    
    ; 写入空格
    mov al, ' '
    call write_char
    
    cmp eax, 1
    je .one_op
    
    ; 两个操作数
    mov esi, tok2
    call find_op_addr
    test eax, eax
    jz .error
    mov esi, eax
    call write_str
    
    mov al, ','
    call write_char
    mov al, ' '
    call write_char
    
    mov esi, tok3
    call find_op_addr
    test eax, eax
    jz .error
    mov esi, eax
    call write_str
    jmp .newline
    
.one_op:
    mov esi, tok2
    call find_op_addr
    test eax, eax
    jz .error
    mov esi, eax
    call write_str
    
.newline:
    mov al, 10
    call write_char
    
    ; 刷新输出
    call flush_output
    jmp .exit
    
.error:
    mov esi, .err_msg
    call write_str
    mov al, 10
    call write_char
    call flush_output
    
.exit:
    popa
    ret
    
.err_msg db "ERROR", 0

; ============================================
; 查找操作数(包装函数)
; ============================================
find_op_addr:
    push esi
    mov esi, [esp + 4]    ; 获取参数
    call find_op
    add esp, 4
    ret

; ============================================
; 写入字符串到输出缓冲区
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
; 写入字符到输出缓冲区
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
; 刷新输出缓冲区到文件
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
