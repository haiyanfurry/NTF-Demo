; ============================================
; decode.asm - 比特模式匹配指令解码器 (跨平台版)
; ============================================
; 功能: 
;   1. 从 input.asm 读取原始字节
;   2. 使用 cpuhdr.asm 解析的 CPU 定义表进行位模式匹配
;   3. 生成 IR (中间表示) 条目
;
; IR 条目结构 (在内存中):
;   IR_ENTRY: 
;     +0:  mnemonic_ptr  (8字节, 指向助记符字符串)
;     +8:  operand_ptrs  (8*4=32字节, 最多4个操作数指针)
;    +40:  op_count      (8字节)
;    +48:  raw_bytes[4]  (4字节)
;    +52:  insn_size     (1字节)
;    +53:  (padding 3字节)
;    = 56 字节每个条目
;
; IR 缓冲区: 循环队列, 最大 256 条目
;
; 导出的函数:
;   decode_next_instruction() → rax=0(成功)/-1(EOF)
;   get_ir_entry(rdi=索引) → rax=IR条目指针
;   ir_entry_count → 当前 IR 条目数
;   clear_ir_buffer()
; ============================================

default rel

%include "config.inc"
%include "cpu_defs.inc"
%include "ir_defs.inc"

; ============================================
; 导出符号
; ============================================
global decode_next_instruction
global get_ir_entry
global ir_entry_count
global clear_ir_buffer
global IR_ENTRY_SIZE

; ============================================
; 外部引用
; ============================================
extern read_next_byte
extern find_insn_by_bits
extern lookup_field_value
extern insn_table
extern insn_count
extern field_table
extern field_count

; ============================================
; BSS
; ============================================
section .bss
ir_buffer       resb MAX_IR_ENTRIES * IR_ENTRY_SIZE
ir_entry_count  resq 1
ir_write_pos    resq 1         ; 当前写入位置 (字节偏移)

; 临时 IR 条目 (用于构建)
temp_ir         resb IR_ENTRY_SIZE

; 默认字符串
str_unknown     resb 16        ; "unknown" 存储空间
str_hex_prefix  resb 16        ; "0x" 存储空间

section .text

; ============================================
; decode_next_instruction: 解码下一条指令
; 输出: rax = 0 (成功), -1 (EOF)
;
; 处理流程:
;   1. 从 input.asm 读取下一个字节
;   2. 在 insn_table 中查找匹配的指令
;   3. 如果匹配: 提取操作数, 构建 IR 条目
;   4. 如果不匹配: 创建 "db 0xNN" IR 条目
;   5. 将 IR 条目写入 ir_buffer
; ============================================
decode_next_instruction:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    push r12
    push r13
    push r14
    push r15

    ; 读取下一个字节
    call read_next_byte
    cmp rax, -1
    je .eof

    mov r12, rax           ; r12 = 原始字节值

    ; 清零临时 IR 条目
    load_addr rdi, temp_ir
    mov rcx, IR_ENTRY_SIZE / 8
    xor rax, rax
    rep stosq
    ; 确保最后几个字节也清零
    mov byte [temp_ir + IR_SIZE_OFF], 1  ; 默认指令大小=1

    ; 在指令表中查找
    mov rax, r12
    call find_insn_by_bits
    test rax, rax
    jz .unknown_byte      ; 未找到 → db 0xNN

    mov r13, rax           ; r13 = 指令条目指针

    ; --- 匹配成功: 构建 IR ---

    ; 1. 设置助记符
    mov rax, [r13 + INSN_NAME_OFF]
    load_addr rbx, temp_ir
    mov [rbx + IR_MNEMONIC_OFF], rax

    ; 2. 设置原始字节
    mov [rbx + IR_RAW_OFF], r12b

    ; 3. 设置操作数计数
    xor rcx, rcx
    mov cl, [r13 + INSN_OPCOUNT_OFF]
    mov [rbx + IR_OPCOUNT_OFF], rcx

    ; 4. 解析操作数字段
    test rcx, rcx
    jz .finish_entry       ; 没有操作数

    xor r14, r14           ; 操作数索引
.op_loop:
    cmp r14, 4             ; 最多4个操作数
    jge .finish_entry
    cmp r14, rcx
    jge .finish_entry

    ; 获取字段索引
    xor r15, r15
    mov r15b, [r13 + INSN_OPS_OFF + r14]

    ; 获取字段条目指针
    load_addr rbx, field_table
    mov rax, r15
    imul rax, FIELD_ENTRY_SIZE
    add rbx, rax            ; rbx = 字段条目指针

    ; 从原始字节中提取字段值
    mov rax, [rbx + FIELD_BITMASK_OFF]   ; bitmask
    and rax, r12                          ; 应用掩码
    xor rcx, rcx
    mov cl, [rbx + FIELD_SHIFT_OFF]       ; shift
    shr rax, cl                           ; 右移对齐 (只能用 CL 或立即数)

    ; 检查是否是立即数字段
    cmp byte [rbx + FIELD_IS_IMM_OFF], 0
    jne .as_immediate

    ; 查找字段值名称
    mov rdi, rbx
    call lookup_field_value
    test rax, rax
    jnz .store_operand

    ; 未找到 → 作为十六进制值输出
    ; 构建 "0xNN" 字符串
    jmp .as_immediate

.store_operand:
    ; 存储操作数指针到 IR 条目
    load_addr rbx, temp_ir
    mov [rbx + IR_OP1_OFF + r14 * 8], rax
    inc r14
    jmp .op_loop

.as_immediate:
    ; 立即数操作数: 使用原始值
    ; 简化: 直接存储数值 (后续 codegen 处理)
    ; 暂时存储为数值指针的特殊标记
    ; 更简单的处理: 跳过，先放空
    inc r14
    jmp .op_loop

.finish_entry:
    ; 将临时 IR 条目写入 IR 缓冲区
    call write_ir_entry

    xor rax, rax
    jmp .exit

.unknown_byte:
    ; 未匹配: 创建 "db 0xNN" 条目
    load_addr rbx, temp_ir

    ; 助记符 = "db"
    load_addr rax, str_db
    mov [rbx + IR_MNEMONIC_OFF], rax

    ; 操作数 = "0xNN"
    load_addr rdi, temp_hex_str
    call format_hex_byte    ; r12 = 字节值

    ; 操作数指针指向 temp_hex_str
    load_addr rax, temp_hex_str
    mov [rbx + IR_OP1_OFF], rax
    mov qword [rbx + IR_OPCOUNT_OFF], 1

    ; 原始字节
    mov [rbx + IR_RAW_OFF], r12b

    call write_ir_entry
    xor rax, rax
    jmp .exit

.eof:
    mov rax, -1

.exit:
    pop r15
    pop r14
    pop r13
    pop r12
    leave
    ret

; ============================================
; write_ir_entry: 将 temp_ir 写入 ir_buffer
; ============================================
write_ir_entry:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    push r12

    ; 检查是否已满
    load_addr rbx, ir_entry_count
    mov rax, [rbx]
    cmp rax, MAX_IR_ENTRIES
    jge .exit

    ; 计算写入位置
    load_addr r12, ir_buffer
    imul rax, IR_ENTRY_SIZE
    add r12, rax

    ; 复制 temp_ir 到 ir_buffer
    load_addr rsi, temp_ir
    mov rdi, r12
    mov rcx, IR_ENTRY_SIZE / 8
    rep movsq

    ; 更新计数
    load_addr rbx, ir_entry_count
    inc qword [rbx]

.exit:
    pop r12
    leave
    ret

; ============================================
; get_ir_entry: 获取 IR 条目指针
; 输入: rdi = 索引 (0-based)
; 输出: rax = IR 条目指针 (0 = 越界)
; ============================================
get_ir_entry:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    load_addr rbx, ir_entry_count
    mov rax, [rbx]
    cmp rdi, rax
    jge .out_of_range

    load_addr rax, ir_buffer
    imul rdi, IR_ENTRY_SIZE
    add rax, rdi

    leave
    ret

.out_of_range:
    xor rax, rax
    leave
    ret

; ============================================
; clear_ir_buffer: 清空 IR 缓冲区
; ============================================
clear_ir_buffer:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    load_addr rbx, ir_entry_count
    mov qword [rbx], 0

    leave
    ret

; ============================================
; format_hex_byte: 格式化字节为十六进制字符串
; 输入: rdi = 目标缓冲区 (至少 5 字节)
;        r12 = 字节值
; 输出: 写入 "0xNN\0" 到缓冲区
; ============================================
format_hex_byte:
    push rbp
    mov rbp, rsp
    push rbx

    mov [rdi], byte '0'
    mov [rdi+1], byte 'x'
    mov [rdi+4], byte 0

    mov al, r12b
    shr al, 4
    call nybble_to_hex
    mov [rdi+2], al

    mov al, r12b
    and al, 0x0F
    call nybble_to_hex
    mov [rdi+3], al

    pop rbx
    leave
    ret

; ============================================
; nybble_to_hex: 半字节转十六进制字符
; 输入: al = 0-15
; 输出: al = '0'-'9' 或 'A'-'F'
; ============================================
nybble_to_hex:
    push rbp
    mov rbp, rsp
    cmp al, 9
    jbe .digit
    add al, 'A' - 10
    jmp .exit
.digit:
    add al, '0'
.exit:
    leave
    ret

; ============================================
; 静态数据
; ============================================
section .data
str_db:          db "db", 0

; ============================================
; BSS: 临时十六进制字符串缓冲区
; ============================================
section .bss
temp_hex_str     resb 16    ; 用于格式化 "0xNN"
