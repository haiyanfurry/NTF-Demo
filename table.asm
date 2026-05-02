global find_instruction_handler
global find_operand_name
global str_nop, str_mov, str_add, str_sub, str_mul
global str_inc, str_dec, str_xor, str_jmp, str_push, str_pop
global str_print

global str_reg_ax, str_reg_bx, str_reg_cx, str_reg_dx
global str_imm_0, str_imm_1, str_imm_2, str_imm_3
global str_imm_5, str_imm_10, str_imm_99

extern token_opcode, token_op1, token_op2

section .data
; 指令名称字符串
str_nop:     db "nop", 0
str_mov:     db "mov", 0
str_add:     db "add", 0
str_sub:     db "sub", 0
str_mul:     db "mul", 0
str_inc:     db "inc", 0
str_dec:     db "dec", 0
str_xor:     db "xor", 0
str_jmp:     db "jmp", 0
str_push:    db "push", 0
str_pop:     db "pop", 0
str_print:   db "print", 0

; 操作数名称字符串
str_reg_ax:  db "ax", 0
str_reg_bx:  db "bx", 0
str_reg_cx:  db "cx", 0
str_reg_dx:  db "dx", 0
str_imm_0:   db "0", 0
str_imm_1:   db "1", 0
str_imm_2:   db "2", 0
str_imm_3:   db "3", 0
str_imm_5:   db "5", 0
str_imm_10:  db "10", 0
str_imm_99:  db "99", 0

; 操作数二进制码字符串
str_00x00000: db "00x00000", 0
str_00x00001: db "00x00001", 0
str_00x00002: db "00x00002", 0
str_00x00003: db "00x00003", 0
str_00x00004: db "00x00004", 0
str_00x00017: db "00x00017", 0
str_00x00018: db "00x00018", 0
str_00x00019: db "00x00019", 0
str_00x00021: db "00x00021", 0
str_00x00023: db "00x00023", 0
str_00x00027: db "00x00027", 0

; 指令处理函数（外部声明）
extern handle_nop, handle_mov, handle_add, handle_sub
extern handle_mul, handle_inc, handle_dec, handle_xor
extern handle_jmp, handle_push, handle_pop
extern handle_print

section .data
; 指令查找表
INST_TAB:
    db "00000", 0, 0, 0
    dq handle_nop
    db "00001", 0, 0, 0
    dq handle_mov
    db "00010", 0, 0, 0
    dq handle_add
    db "00011", 0, 0, 0
    dq handle_sub
    db "00100", 0, 0, 0
    dq handle_mul
    db "00110", 0, 0, 0
    dq handle_inc
    db "00111", 0, 0, 0
    dq handle_dec
    db "01010", 0, 0, 0
    dq handle_xor
    db "01101", 0, 0, 0
    dq handle_jmp
    db "10011", 0, 0, 0
    dq handle_push
    db "10100", 0, 0, 0
    dq handle_pop
    db "10101", 0, 0, 0
    dq handle_print
INST_COUNT equ 12
INST_ENTRY_SIZE equ 16

; 操作数查找表
OP_TAB:
    db "00x00000", 0, 0, 0, 0
    dq str_imm_0
    db "00x00001", 0, 0, 0, 0
    dq str_reg_ax
    db "00x00002", 0, 0, 0, 0
    dq str_reg_bx
    db "00x00003", 0, 0, 0, 0
    dq str_reg_cx
    db "00x00004", 0, 0, 0, 0
    dq str_reg_dx
    db "00x00017", 0, 0, 0, 0
    dq str_imm_1
    db "00x00018", 0, 0, 0, 0
    dq str_imm_2
    db "00x00019", 0, 0, 0, 0
    dq str_imm_3
    db "00x00021", 0, 0, 0, 0
    dq str_imm_5
    db "00x00023", 0, 0, 0, 0
    dq str_imm_10
    db "00x00027", 0, 0, 0, 0
    dq str_imm_99
OP_COUNT equ 12
OP_ENTRY_SIZE equ 24

section .text
find_instruction_handler:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    mov rbx, INST_TAB
    mov rcx, INST_COUNT
    
.search_loop:
    mov rsi, token_opcode
    mov rdi, rbx
    mov r8, 5
.compare_loop:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .next
    inc rsi
    inc rdi
    dec r8
    jnz .compare_loop
    jmp .found
.next:
    add rbx, INST_ENTRY_SIZE
    loop .search_loop
    
    jmp .exit
    
.found:
    call [rbx + 8]
    
.exit:
    leave
    ret

find_operand_name:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    
    ; 保存token的地址
    mov r8, rsi
    
    ; 检查00x00000
    mov rsi, r8
    mov rdi, str_00x00000
    call strcmp
    test rax, rax
    je .found_00x00000
    
    ; 检查00x00001
    mov rsi, r8
    mov rdi, str_00x00001
    call strcmp
    test rax, rax
    je .found_00x00001
    
    ; 检查00x00002
    mov rsi, r8
    mov rdi, str_00x00002
    call strcmp
    test rax, rax
    je .found_00x00002
    
    ; 检查00x00003
    mov rsi, r8
    mov rdi, str_00x00003
    call strcmp
    test rax, rax
    je .found_00x00003
    
    ; 检查00x00004
    mov rsi, r8
    mov rdi, str_00x00004
    call strcmp
    test rax, rax
    je .found_00x00004
    
    ; 检查00x00017
    mov rsi, r8
    mov rdi, str_00x00017
    call strcmp
    test rax, rax
    je .found_00x00017
    
    ; 检查00x00018
    mov rsi, r8
    mov rdi, str_00x00018
    call strcmp
    test rax, rax
    je .found_00x00018
    
    ; 检查00x00019
    mov rsi, r8
    mov rdi, str_00x00019
    call strcmp
    test rax, rax
    je .found_00x00019
    
    ; 检查00x00021
    mov rsi, r8
    mov rdi, str_00x00021
    call strcmp
    test rax, rax
    je .found_00x00021
    
    ; 检查00x00023
    mov rsi, r8
    mov rdi, str_00x00023
    call strcmp
    test rax, rax
    je .found_00x00023
    
    ; 检查00x00027
    mov rsi, r8
    mov rdi, str_00x00027
    call strcmp
    test rax, rax
    je .found_00x00027
    
    ; 没有找到匹配的操作数
    xor rax, rax
    jmp .exit
    
.found_00x00000:
    mov rax, str_imm_0
    jmp .exit
    
.found_00x00001:
    mov rax, str_reg_ax
    jmp .exit
    
.found_00x00002:
    mov rax, str_reg_bx
    jmp .exit
    
.found_00x00003:
    mov rax, str_reg_cx
    jmp .exit
    
.found_00x00004:
    mov rax, str_reg_dx
    jmp .exit
    
.found_00x00017:
    mov rax, str_imm_1
    jmp .exit
    
.found_00x00018:
    mov rax, str_imm_2
    jmp .exit
    
.found_00x00019:
    mov rax, str_imm_3
    jmp .exit
    
.found_00x00021:
    mov rax, str_imm_5
    jmp .exit
    
.found_00x00023:
    mov rax, str_imm_10
    jmp .exit
    
.found_00x00027:
    mov rax, str_imm_99
    jmp .exit
    
.exit:
    leave
    ret

strcmp:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
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
