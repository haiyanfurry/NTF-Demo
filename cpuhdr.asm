; ============================================
; cpuhdr.asm - CPU 头文件 DSL 解析器 (跨平台版)
; ============================================
; 功能: 解析 .hdr CPU 定义文件，构建内存中的
;       指令查找表和操作数字段表。
;
; 导出的核心数据结构:
;   insn_table     - 指令表 (数组, 每个条目 32 字节)
;   insn_count     - 指令数量
;   field_table    - 字段表 (数组, 每个条目 24 字节)
;   field_count    - 字段数量
;
; 导出的函数:
;   parse_cpu_header(rdi=文件路径) → rax=0(成功)/-1(失败)
;   find_insn_by_bits(rax=原始字节) → rax=insn_entry_ptr (0=未找到)
;   lookup_field_value(rdi=field_ptr, rax=raw_value) → rax=name_ptr
; ============================================

%include "config.inc"

; ============================================
; 数据结构常量定义
; ============================================
INSN_ENTRY_SIZE     equ 32   ; 每条指令 32 字节
INSN_MASK_OFF       equ 0    ; mask     (8 字节)
INSN_PATTERN_OFF    equ 8    ; pattern  (8 字节)
INSN_NAME_OFF       equ 16   ; name_ptr (8 字节)
INSN_OPCOUNT_OFF    equ 24   ; op_count (1 字节)
INSN_OPS_OFF        equ 25   ; op_fields[7] (7 字节, 字段索引数组)

MAX_INSTRUCTIONS    equ 64
MAX_FIELDS          equ 16
MAX_VALUES          equ 16

FIELD_ENTRY_SIZE    equ 24
FIELD_NAME_OFF      equ 0    ; name_ptr   (8 字节)
FIELD_BITMASK_OFF   equ 8    ; bitmask    (8 字节)
FIELD_SHIFT_OFF     equ 16   ; shift      (1 字节)
FIELD_VALCOUNT_OFF  equ 17   ; val_count  (1 字节)
FIELD_IS_IMM_OFF    equ 18   ; is_imm     (1 字节)
FIELD_VALTAB_OFF    equ 19   ; val_table_ptr (8 字节, 调整对齐)
; 注意: 24 字节对齐

VALUE_ENTRY_SIZE    equ 16
VALUE_PATTERN_OFF   equ 0    ; pattern   (8 字节)
VALUE_NAME_OFF      equ 8    ; name_ptr  (8 字节)

LINE_BUF_SIZE       equ 256
TOKEN_BUF_SIZE      equ 64

; ============================================
; 导出符号
; ============================================
global parse_cpu_header
global find_insn_by_bits
global lookup_field_value
global insn_table
global insn_count
global field_table
global field_count

; ============================================
; BSS: 运行时数据结构
; ============================================
section .bss
; 指令表
insn_table      resb MAX_INSTRUCTIONS * INSN_ENTRY_SIZE
insn_count      resq 1

; 字段表
field_table     resb MAX_FIELDS * FIELD_ENTRY_SIZE
field_count     resq 1

; 值表存储池 (每个字段最多 16 个值)
val_storage     resb MAX_FIELDS * MAX_VALUES * VALUE_ENTRY_SIZE

; 字符串存储池 (存储所有解析出的名称字符串)
str_pool        resb 4096
str_pool_pos    resq 1

; 解析缓冲区
hdr_line_buf    resb LINE_BUF_SIZE
token_buf       resb TOKEN_BUF_SIZE
token_buf2      resb TOKEN_BUF_SIZE
token_buf3      resb TOKEN_BUF_SIZE
char_buf        resb 1

; 头文件句柄/描述符
hdr_fd          resq 1

section .text

; ============================================
; parse_cpu_header: 解析 CPU 头文件
; 输入: rdi = 文件路径 (以 0 结尾的字符串)
; 输出: rax = 0 (成功), -1 (失败)
;
; 破坏: rax, rbx, rcx, rdx, rsi, rdi, r8, r9, r10, r11, r12, r13
; ============================================
parse_cpu_header:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; 初始化
    load_addr rbx, insn_count
    mov qword [rbx], 0
    load_addr rbx, field_count
    mov qword [rbx], 0
    load_addr rbx, str_pool_pos
    mov qword [rbx], 0

    ; 打开头文件 (rdi 已经指向路径)
    xor rsi, rsi       ; O_RDONLY
    xor rdx, rdx
    sys_open
    test rax, rax
    js .error

    load_addr rbx, hdr_fd
    mov [rbx], rax

    ; 主解析循环: 逐行读取
.parse_loop:
    call read_hdr_line
    test rax, rax
    jz .done            ; EOF

    ; 跳过空行和注释
    load_addr rsi, hdr_line_buf
    mov al, [rsi]
    cmp al, 0
    je .parse_loop
    cmp al, ';'
    je .parse_loop
    cmp al, 10
    je .parse_loop
    cmp al, 13
    je .parse_loop

    ; 解析第一个 token 确定语句类型
    load_addr rsi, hdr_line_buf
    load_addr rdi, token_buf
    call get_token_cpuhdr
    ; 现在 token_buf 包含第一个词

    ; 检查关键字
    load_addr rsi, token_buf
    call is_keyword_arch
    test rax, rax
    jnz .parse_arch

    load_addr rsi, token_buf
    call is_keyword_insn
    test rax, rax
    jnz .parse_insn

    load_addr rsi, token_buf
    call is_keyword_field
    test rax, rax
    jnz .parse_field

    ; 跳过缩进行 (值映射行)
    mov al, [token_buf]
    cmp al, ' '
    je .parse_loop
    cmp al, 9          ; tab
    je .parse_loop

    ; 未知关键字，跳过
    jmp .parse_loop

.parse_arch:
    ; arch "name" - 简单跳过，暂不处理
    jmp .parse_loop

.parse_insn:
    ; 格式: 指令 <name> mask=0x... pattern=0x... [operands=...]
    ; 当前 rsi 指向 mask token
    call parse_insn_stmt
    jmp .parse_loop

.parse_field:
    ; 格式: 字段 <name> bits=N:M [type=...]
    ; 后续缩进行: <name> value=...
    call parse_field_stmt
    jmp .parse_loop

.done:
    ; 关闭头文件
    load_addr rbx, hdr_fd
    mov rdi, [rbx]
    sys_close

    xor rax, rax
    leave
    ret

.error:
    mov rax, -1
    leave
    ret

; ============================================
; read_hdr_line: 从头文件读取一行
; 输出: rax = 行长度 (0 = EOF)
;       全局 hdr_line_buf 包含行内容 (0 结尾)
; ============================================
read_hdr_line:
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 32

    ; 清空行缓冲区
    load_addr rdi, hdr_line_buf
    mov rcx, LINE_BUF_SIZE
    xor rax, rax
    rep stosb

    xor r12, r12
.read_loop:
    ; sys_read(rdi=hdr_fd, rsi=char_buf, rdx=1)
    load_addr rbx, hdr_fd
    mov rdi, [rbx]
    load_addr rsi, char_buf
    mov rdx, 1
    sys_read

    test rax, rax
    jz .eof
    js .eof

    load_addr rbx, char_buf
    mov al, [rbx]
    cmp al, 10
    je .line_end
    cmp al, 13
    je .line_end

    ; 存储字符
    load_addr rbx, hdr_line_buf
    mov [rbx + r12], al
    inc r12
    cmp r12, LINE_BUF_SIZE - 2
    jl .read_loop

.line_end:
    ; 0 结尾
    load_addr rbx, hdr_line_buf
    mov byte [rbx + r12], 0

    mov rax, r12
    jmp .exit

.eof:
    xor rax, rax

.exit:
    add rsp, 32
    pop r12
    pop rbp
    ret

; ============================================
; get_token_cpuhdr: 从行中提取下一个 token
; 输入: rsi = 源字符串指针
;        rdi = 目标缓冲区
; 输出: rax = 更新后的源字符串指针
; ============================================
get_token_cpuhdr:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    cmp rdi, 0
    je .exit
    mov byte [rdi], 0
    cmp rsi, 0
    je .exit

.skip_spaces:
    mov al, [rsi]
    cmp al, 0
    je .exit
    cmp al, ' '
    je .skip_space
    cmp al, 9
    je .skip_space
    jmp .copy

.skip_space:
    inc rsi
    jmp .skip_spaces

.copy:
    mov [rdi], al
    inc rdi
    inc rsi
    mov al, [rsi]

    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    cmp al, 9
    je .done
    cmp al, 10
    je .done
    cmp al, 13
    je .done

    jmp .copy

.done:
    mov byte [rdi], 0

.exit:
    mov rax, rsi
    leave
    ret

; ============================================
; 关键字检测函数
; ============================================
is_keyword_arch:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    load_addr rdi, str_arch
    call strcmp_cpuhdr
    test rax, rax
    jz .yes
    xor rax, rax
    jmp .exit
.yes:
    mov rax, 1
.exit:
    leave
    ret

is_keyword_insn:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    load_addr rdi, str_insn
    call strcmp_cpuhdr
    test rax, rax
    jz .yes
    xor rax, rax
    jmp .exit
.yes:
    mov rax, 1
.exit:
    leave
    ret

is_keyword_field:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    load_addr rdi, str_field
    call strcmp_cpuhdr
    test rax, rax
    jz .yes
    xor rax, rax
    jmp .exit
.yes:
    mov rax, 1
.exit:
    leave
    ret

; ============================================
; parse_insn_stmt: 解析指令语句
; 输入: rsi = 指向 "mask=" token 的指针
;
; 格式: 指令 <name> mask=0xNN pattern=0xNN [operands=a,b,c]
; 
; 解析后写入 insn_table[insn_count]
; ============================================
parse_insn_stmt:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    push r12
    push r13
    push r14
    push r15

    ; 检查是否已满
    load_addr rbx, insn_count
    mov rax, [rbx]
    cmp rax, MAX_INSTRUCTIONS
    jge .exit

    ; 计算当前条目指针: insn_table + insn_count * INSN_ENTRY_SIZE
    load_addr r12, insn_table
    mov r13, rax           ; r13 = insn_count
    imul r13, INSN_ENTRY_SIZE
    add r12, r13           ; r12 = 当前指令条目指针

    ; r14 = 操作数索引数组的写入位置 (在条目内偏移 INSN_OPS_OFF)
    mov r14, 0             ; 操作数计数

    ; 初始化条目 (清零)
    push r12
    mov rdi, r12
    mov rcx, INSN_ENTRY_SIZE / 8
    xor rax, rax
    rep stosq
    pop r12

    ; 注意: 此时 rsi 是上一个 get_token 返回的位置
    ; 我们需要重新解析整行
    ; 简化: 重新读取行缓冲区的 token

    ; 定位到行首 (hdr_line_buf)
    load_addr r13, hdr_line_buf

    ; 跳过 "指令" 关键字
    mov rsi, r13
    load_addr rdi, token_buf
    call get_token_cpuhdr    ; 跳过 "指令"
    mov r13, rax

    ; 读取指令名称
    mov rsi, r13
    load_addr rdi, token_buf
    call get_token_cpuhdr    ; 指令名称
    mov r13, rax

    ; 存储指令名称到 str_pool
    load_addr rdi, token_buf
    load_addr rsi, str_pool
    load_addr rbx, str_pool_pos
    add rsi, [rbx]
    mov rdi, rsi            ; rsi = str_pool + str_pool_pos
    load_addr r8, token_buf
    call strcpy_cpuhdr

    ; 更新 name_ptr
    load_addr rbx, str_pool_pos
    mov [r12 + INSN_NAME_OFF], rsi
    ; 更新 str_pool_pos
    load_addr rdi, token_buf
    call strlen_cpuhdr
    add [rbx], rax
    inc qword [rbx]         ; +1 for null terminator

    ; 循环解析参数: mask=, pattern=, operands=, size=
.next_param:
    mov rsi, r13
    load_addr rdi, token_buf
    call get_token_cpuhdr
    mov r13, rax

    load_addr rsi, token_buf
    mov al, [rsi]
    cmp al, 0
    je .finish_insn

    ; 检查是 mask= 还是 pattern= 还是 operands= 还是 size=
    load_addr rdi, str_mask_prefix
    call str_startswith
    test rax, rax
    jnz .parse_mask

    load_addr rdi, str_pattern_prefix
    call str_startswith
    test rax, rax
    jnz .parse_pattern

    load_addr rdi, str_operands_prefix
    call str_startswith
    test rax, rax
    jnz .parse_operands

    load_addr rdi, str_size_prefix
    call str_startswith
    test rax, rax
    jnz .parse_size

    jmp .next_param

.parse_mask:
    ; 解析 mask=0xNN 的值部分
    load_addr rsi, token_buf
    load_addr rdi, str_mask_prefix
    call str_len_prefix   ; 获取前缀长度
    ; rsi 指向值起始位置
    add rsi, rax
    call parse_hex_value
    mov [r12 + INSN_MASK_OFF], rax
    jmp .next_param

.parse_pattern:
    ; 解析 pattern=0xNN
    load_addr rsi, token_buf
    load_addr rdi, str_pattern_prefix
    call str_len_prefix
    add rsi, rax
    call parse_hex_value
    mov [r12 + INSN_PATTERN_OFF], rax
    jmp .next_param

.parse_operands:
    ; 解析 operands=a,b,c
    ; 跳过 "operands=" 前缀
    load_addr rsi, token_buf
    load_addr rdi, str_operands_prefix
    call str_len_prefix
    add rsi, rax
    ; rsi 指向逗号分隔的字段名列表
    ; 对每个字段名:
    ;   1. 在 field_table 中查找匹配的字段
    ;   2. 记录字段索引到 op_fields[]
.parse_oplist:
    load_addr rdi, token_buf2
    call get_token_comma
    ; token_buf2 包含字段名
    load_addr rsi, token_buf2
    mov al, [rsi]
    cmp al, 0
    je .next_param

    ; 在 field_table 中查找字段索引
    push rsi
    push r12
    push r14
    mov rdi, rsi        ; rdi = 字段名
    call find_field_by_name
    pop r14
    pop r12
    pop rsi

    cmp rax, -1
    je .skip_op

    ; 字段索引在 al 中 (0-15)
    cmp r14, 7
    jge .skip_op

    mov byte [r12 + INSN_OPS_OFF + r14], al
    inc r14

.skip_op:
    ; 检查是否还有更多 (当前 rsi 指向逗号或之后)
    jmp .parse_oplist

.parse_size:
    ; 解析 size=N
    load_addr rsi, token_buf
    load_addr rdi, str_size_prefix
    call str_len_prefix
    add rsi, rax
    call parse_decimal_value
    ; 暂存 size 到 op_count 字节的高位? 
    ; 或者使用专门的 size 字段
    ; 简化版: 暂不处理 size
    jmp .next_param

.finish_insn:
    ; 更新操作数计数
    mov [r12 + INSN_OPCOUNT_OFF], r14b

    ; 增加指令计数
    load_addr rbx, insn_count
    inc qword [rbx]

.exit:
    pop r15
    pop r14
    pop r13
    pop r12
    leave
    ret

; ============================================
; parse_field_stmt: 解析字段语句
; 输入: rsi = 指向 "bits=" 的指针
; ============================================
parse_field_stmt:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    push r12
    push r13
    push r14
    push r15

    ; 检查是否已满
    load_addr rbx, field_count
    mov rax, [rbx]
    cmp rax, MAX_FIELDS
    jge .exit

    ; 计算字段条目指针
    load_addr r12, field_table
    mov r13, rax
    imul r13, FIELD_ENTRY_SIZE
    add r12, r13

    ; 清零条目
    push r12
    mov rdi, r12
    mov rcx, FIELD_ENTRY_SIZE / 8
    xor rax, rax
    rep stosq
    pop r12

    ; 重新解析行
    load_addr r13, hdr_line_buf

    ; 跳过 "字段" 关键字
    mov rsi, r13
    load_addr rdi, token_buf
    call get_token_cpuhdr
    mov r13, rax

    ; 读取字段名称
    mov rsi, r13
    load_addr rdi, token_buf
    call get_token_cpuhdr
    mov r13, rax

    ; 存储字段名称到 str_pool
    load_addr rdi, token_buf
    load_addr rsi, str_pool
    load_addr rbx, str_pool_pos
    add rsi, [rbx]
    mov rdi, rsi
    load_addr r8, token_buf
    call strcpy_cpuhdr

    mov [r12 + FIELD_NAME_OFF], rsi
    load_addr rbx, str_pool_pos
    load_addr rdi, token_buf
    call strlen_cpuhdr
    add [rbx], rax
    inc qword [rbx]

    ; 循环解析参数
.next_param:
    mov rsi, r13
    load_addr rdi, token_buf
    call get_token_cpuhdr
    mov r13, rax

    load_addr rsi, token_buf
    mov al, [rsi]
    cmp al, 0
    je .done_field

    ; bits=N:M
    load_addr rdi, str_bits_prefix
    call str_startswith
    test rax, rax
    jnz .parse_bits

    ; type=...
    load_addr rdi, str_type_prefix
    call str_startswith
    test rax, rax
    jnz .parse_type

    jmp .next_param

.parse_bits:
    ; 解析 bits=4:2
    load_addr rsi, token_buf
    load_addr rdi, str_bits_prefix
    call str_len_prefix
    add rsi, rax
    ; rsi 指向 "4:2" 格式
    call parse_bits_range
    ; rax = bitmask, rdx = shift
    mov [r12 + FIELD_BITMASK_OFF], rax
    mov byte [r12 + FIELD_SHIFT_OFF], dl
    jmp .next_param

.parse_type:
    ; type=immediate 或 type=string
    ; 设置 is_imm 标志
    mov byte [r12 + FIELD_IS_IMM_OFF], 1
    jmp .next_param

.done_field:
    ; 接下来需要读取缩进的值映射行
    ; 这些行在后续的 parse_loop 中处理
    ; 但我们需要从 hdr_line_buf 获取后续行
    ; 临时方案: 这里先增加 field_count
    ; 值映射在 parse_value_mappings 中通过读取后续行完成

    ; 记录当前字段索引以便值映射关联
    load_addr rbx, field_count
    mov rax, [rbx]
    ; 保存到 r15
    mov r15, rax

    ; 为值表分配存储空间
    ; val_storage + field_index * MAX_VALUES * VALUE_ENTRY_SIZE
    load_addr r14, val_storage
    imul rax, MAX_VALUES * VALUE_ENTRY_SIZE
    add r14, rax

    ; 设置值表指针
    mov [r12 + FIELD_VALTAB_OFF], r14

    ; 现在读取后续行，寻找缩进的值映射
    xor r12, r12         ; 值计数

.read_val_loop:
    ; 保存当前现场
    push r12
    push r14
    push r15

    call read_hdr_line
    pop r15
    pop r14
    pop r12

    test rax, rax
    jz .finish_field

    ; 检查是否是缩进行 (以空格或 tab 开头)
    load_addr rsi, hdr_line_buf
    mov al, [rsi]
    cmp al, ' '
    je .parse_val_line
    cmp al, 9
    je .parse_val_line
    cmp al, ';'
    je .read_val_loop    ; 注释行跳过
    cmp al, 0
    je .read_val_loop

    ; 不是缩进行了，这一行属于下一条语句
    ; 需要"回退"这一行... 在汇编中不好做回退
    ; 简化: 直接停止解析值映射
    jmp .finish_field

.parse_val_line:
    ; 格式: <名称> value=<比特值>
    cmp r12, MAX_VALUES
    jge .read_val_loop

    ; 解析名称
    load_addr rsi, hdr_line_buf
    load_addr rdi, token_buf
    call get_token_cpuhdr

    ; 存储名称到 str_pool
    push r12
    push r14
    push r15

    load_addr rdi, token_buf
    load_addr rsi, str_pool
    load_addr rbx, str_pool_pos
    add rsi, [rbx]
    mov rdi, rsi
    load_addr r8, token_buf
    call strcpy_cpuhdr

    ; 写入值条目
    mov [r14 + VALUE_NAME_OFF], rsi
    load_addr rbx, str_pool_pos
    load_addr rdi, token_buf
    call strlen_cpuhdr
    add [rbx], rax
    inc qword [rbx]

    pop r15
    pop r14
    pop r12

    ; 读取 value= 部分
    ; rsi 现在指向 "value=..." 
    load_addr rdi, token_buf2
    call get_token_cpuhdr

    ; 解析 value=...
    load_addr rsi, token_buf2
    load_addr rdi, str_value_prefix
    call str_startswith
    test rax, rax
    jz .skip_val

    ; 获取值部分
    load_addr rsi, token_buf2
    load_addr rdi, str_value_prefix
    call str_len_prefix
    add rsi, rax

    ; 尝试解析为十六进制或二进制
    call parse_hex_or_bin_value
    mov [r14 + VALUE_PATTERN_OFF], rax

    inc r12
    add r14, VALUE_ENTRY_SIZE

.skip_val:
    jmp .read_val_loop

.finish_field:
    ; 更新值计数
    load_addr rbx, field_table
    load_addr rax, field_count
    mov rax, [rax]
    imul rax, FIELD_ENTRY_SIZE
    add rbx, rax
    mov byte [rbx + FIELD_VALCOUNT_OFF], r12b

    ; 增加字段计数
    load_addr rbx, field_count
    inc qword [rbx]

.exit:
    pop r15
    pop r14
    pop r13
    pop r12
    leave
    ret

; ============================================
; 辅助函数
; ============================================

; strcmp_cpuhdr: 字符串比较
; 输入: rsi = 字符串1, rdi = 字符串2
; 输出: rax = 0 (相等), 非0 (不等)
strcmp_cpuhdr:
    push rbp
    mov rbp, rsp
.loop:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .not_equal
    test al, al
    jz .equal
    inc rsi
    inc rdi
    jmp .loop
.equal:
    xor rax, rax
    jmp .exit
.not_equal:
    mov rax, 1
.exit:
    leave
    ret

; strcpy_cpuhdr: 字符串复制
; 输入: rsi = 源, rdi = 目标
strcpy_cpuhdr:
    push rbp
    mov rbp, rsp
.loop:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .done
    inc rsi
    inc rdi
    jmp .loop
.done:
    leave
    ret

; strlen_cpuhdr: 字符串长度
; 输入: rdi = 字符串
; 输出: rax = 长度
strlen_cpuhdr:
    push rbp
    mov rbp, rsp
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    leave
    ret

; str_startswith: 检查字符串是否以指定前缀开头
; 输入: rsi = 待检查字符串, rdi = 前缀
; 输出: rax = 0 (不是), 非0 (是)
str_startswith:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi
.loop:
    mov al, [rdi]
    test al, al
    jz .yes           ; 前缀遍历完，匹配
    mov dl, [rsi]
    cmp dl, al
    jne .no
    inc rsi
    inc rdi
    jmp .loop
.yes:
    mov rax, 1
    jmp .exit
.no:
    xor rax, rax
.exit:
    pop rdi
    pop rsi
    leave
    ret

; str_len_prefix: 获取前缀字符串长度
; 输入: rdi = 前缀字符串
; 输出: rax = 长度
str_len_prefix:
    push rbp
    mov rbp, rsp
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    leave
    ret

; get_token_comma: 获取逗号分隔的 token
; 输入: rsi = 源字符串, rdi = 目标缓冲区
; 输出: rax = 更新后的源指针
get_token_comma:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    cmp rdi, 0
    je .exit
    mov byte [rdi], 0
    cmp rsi, 0
    je .exit

    ; 跳过空格
.skip_spaces:
    mov al, [rsi]
    cmp al, 0
    je .exit
    cmp al, ' '
    je .skip_space
    cmp al, 9
    je .skip_space
    jmp .copy

.skip_space:
    inc rsi
    jmp .skip_spaces

.copy:
    cmp al, ','
    je .done
    cmp al, 0
    je .done
    cmp al, ' '
    je .done

    mov [rdi], al
    inc rdi
    inc rsi
    mov al, [rsi]
    jmp .copy

.done:
    mov byte [rdi], 0
    ; 跳过逗号
    cmp al, ','
    jne .exit
    inc rsi

.exit:
    mov rax, rsi
    leave
    ret

; parse_hex_value: 解析十六进制数值
; 输入: rsi = 指向 "0xNN" 或 "NN" 格式的字符串
; 输出: rax = 解析后的 64 位值
parse_hex_value:
    push rbp
    mov rbp, rsp
    push rbx

    xor rax, rax
    xor rbx, rbx

    ; 跳过可选的 0x 前缀
    cmp word [rsi], '0x'
    jne .loop
    cmp byte [rsi+1], 'x'
    jne .loop
    cmp byte [rsi+1], 'X'
    jne .skip_prefix_check
    jmp .loop
.skip_prefix_check:
    add rsi, 2

.loop:
    mov bl, [rsi]
    test bl, bl
    jz .done
    cmp bl, ' '
    je .done
    cmp bl, 0
    je .done

    shl rax, 4
    cmp bl, '0'
    jb .done
    cmp bl, '9'
    jbe .digit
    cmp bl, 'A'
    jb .done
    cmp bl, 'F'
    jbe .upper
    cmp bl, 'a'
    jb .done
    cmp bl, 'f'
    jbe .lower
    jmp .done

.digit:
    sub bl, '0'
    add al, bl
    inc rsi
    jmp .loop

.upper:
    sub bl, 'A'
    add bl, 10
    add al, bl
    inc rsi
    jmp .loop

.lower:
    sub bl, 'a'
    add bl, 10
    add al, bl
    inc rsi
    jmp .loop

.done:
    pop rbx
    leave
    ret

; parse_bits_range: 解析位范围 "N:M"
; 输入: rsi = 指向范围字符串
; 输出: rax = bitmask, dl = shift
parse_bits_range:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx

    xor rcx, rcx    ; high_bit
    xor rbx, rbx    ; low_bit

    ; 解析高位
.parse_high:
    mov al, [rsi]
    cmp al, ':'
    je .got_colon
    cmp al, 0
    je .done
    sub al, '0'
    imul rcx, 10
    add rcx, rax
    inc rsi
    jmp .parse_high

.got_colon:
    inc rsi          ; 跳过 ':'

    ; 解析低位
.parse_low:
    mov al, [rsi]
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    sub al, '0'
    imul rbx, 10
    add rbx, rax
    inc rsi
    jmp .parse_low

.done:
    ; 计算 bitmask: 从 low_bit 到 high_bit 的位全为1
    ; 简化实现: 直接用查表或简单循环
    
    ; 计算位数 = high - low + 1
    mov rax, rcx
    sub rax, rbx
    inc rax          ; rax = 位数
    
    ; 构建掩码: 从低位开始设置 N 个 1
    xor rdx, rdx
    mov r8, 1
.build_mask:
    test rax, rax
    jz .shift_mask
    or rdx, r8
    shl r8, 1
    dec rax
    jmp .build_mask
.shift_mask:
    ; rdx = 低位掩码 (如 00001111)
    ; 左移 low 位
    mov rcx, rbx     ; rcx = low bit position
    test rcx, rcx
    jz .no_shift
.shift_loop:
    shl rdx, 1
    dec rcx
    jnz .shift_loop
.no_shift:
    mov rax, rdx     ; rax = 最终 bitmask
    mov dl, bl       ; dl = shift (低位号)

    pop rcx
    pop rbx
    leave
    ret

; parse_decimal_value: 解析十进制数值
; 输入: rsi = 指向十进制数字字符串
; 输出: rax = 解析后的值
parse_decimal_value:
    push rbp
    mov rbp, rsp
    push rbx

    xor rax, rax
.loop:
    mov bl, [rsi]
    test bl, bl
    jz .done
    cmp bl, '0'
    jb .done
    cmp bl, '9'
    ja .done
    imul rax, 10
    sub bl, '0'
    add al, bl
    inc rsi
    jmp .loop
.done:
    pop rbx
    leave
    ret

; parse_hex_or_bin_value: 解析十六进制或二进制数值
; 输入: rsi = 指向值字符串
; 输出: rax = 64位值
parse_hex_or_bin_value:
    push rbp
    mov rbp, rsp

    ; 检查是否是二进制 (以 'b' 结尾)
    push rsi
    xor rcx, rcx
.find_end:
    mov al, [rsi + rcx]
    test al, al
    jz .end_found
    inc rcx
    jmp .find_end
.end_found:
    pop rsi

    cmp rcx, 0
    je .as_hex

    dec rcx
    mov al, [rsi + rcx]
    cmp al, 'b'
    je .parse_binary
    cmp al, 'B'
    jne .as_hex

.parse_binary:
    ; 解析二进制: 如 "00101"
    xor rax, rax
.bin_loop:
    mov bl, [rsi]
    test bl, bl
    jz .done_bin
    cmp bl, '0'
    jb .done_bin
    cmp bl, '1'
    ja .done_bin
    shl rax, 1
    sub bl, '0'
    or al, bl
    inc rsi
    jmp .bin_loop
.done_bin:
    leave
    ret

.as_hex:
    call parse_hex_value
    leave
    ret

; ============================================
; find_field_by_name: 按名称查找字段
; 输入: rdi = 字段名称指针
; 输出: rax = 字段索引 (0-based), -1 = 未找到
; ============================================
find_field_by_name:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push r8

    load_addr r8, field_count
    mov rcx, [r8]
    test rcx, rcx
    jz .not_found

    load_addr rbx, field_table
    xor r8, r8           ; 索引

.loop:
    mov rsi, [rbx + FIELD_NAME_OFF]
    push rcx
    push rbx
    push r8
    call strcmp_cpuhdr
    pop r8
    pop rbx
    pop rcx
    test rax, rax
    jz .found

    add rbx, FIELD_ENTRY_SIZE
    inc r8
    loop .loop

.not_found:
    mov rax, -1
    jmp .exit

.found:
    mov rax, r8

.exit:
    pop r8
    pop rcx
    pop rbx
    leave
    ret

; ============================================
; find_insn_by_bits: 按比特模式查找指令
; 输入: rax = 原始字节 (或字)
; 输出: rax = 指令条目指针 (0 = 未找到)
; ============================================
find_insn_by_bits:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push r8
    push r9

    mov r8, rax          ; r8 = 输入值

    load_addr r9, insn_count
    mov rcx, [r9]
    test rcx, rcx
    jz .not_found

    load_addr rbx, insn_table

.loop:
    mov rax, [rbx + INSN_MASK_OFF]    ; mask
    and rax, r8                        ; masked_value = input & mask
    mov rdx, [rbx + INSN_PATTERN_OFF] ; pattern
    cmp rax, rdx
    je .found

    add rbx, INSN_ENTRY_SIZE
    loop .loop

.not_found:
    xor rax, rax
    jmp .exit

.found:
    mov rax, rbx

.exit:
    pop r9
    pop r8
    pop rcx
    pop rbx
    leave
    ret

; ============================================
; lookup_field_value: 在字段的值表中查找名称
; 输入: rdi = 字段条目指针
;        rax = 原始值 (已移位对齐后的值)
; 输出: rax = 名称指针 (0 = 未找到, 输出 "0xNN")
; ============================================
lookup_field_value:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx

    mov r8, rax          ; r8 = 要查找的值

    ; 获取值表指针
    mov rbx, [rdi + FIELD_VALTAB_OFF]
    test rbx, rbx
    jz .not_found

    ; 获取值计数
    xor rcx, rcx
    mov cl, [rdi + FIELD_VALCOUNT_OFF]
    test rcx, rcx
    jz .not_found

.loop:
    mov rax, [rbx + VALUE_PATTERN_OFF]
    cmp rax, r8
    je .found

    add rbx, VALUE_ENTRY_SIZE
    loop .loop

.not_found:
    xor rax, rax
    jmp .exit

.found:
    mov rax, [rbx + VALUE_NAME_OFF]

.exit:
    pop rdx
    pop rcx
    pop rbx
    leave
    ret

; ============================================
; 静态字符串
; ============================================
section .data
str_arch:           db "arch", 0
str_insn:           db "指令", 0
str_field:          db "字段", 0
str_mask_prefix:    db "mask=", 0
str_pattern_prefix: db "pattern=", 0
str_operands_prefix:db "operands=", 0
str_size_prefix:    db "size=", 0
str_bits_prefix:    db "bits=", 0
str_type_prefix:    db "type=", 0
str_value_prefix:   db "value=", 0
