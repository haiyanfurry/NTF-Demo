; ============================================
; ir_defs.inc - IR (中间表示) 数据结构常量定义
; ============================================
; 本文件由 decode.asm 和 codegen.asm 共享
; ============================================

IR_ENTRY_SIZE   equ 56
IR_MNEMONIC_OFF equ 0      ; 助记符指针 (8)
IR_OP1_OFF      equ 8      ; 操作数1指针 (8)
IR_OP2_OFF      equ 16     ; 操作数2指针 (8)
IR_OP3_OFF      equ 24     ; 操作数3指针 (8)
IR_OP4_OFF      equ 32     ; 操作数4指针 (8)
IR_OPCOUNT_OFF  equ 40     ; 操作数计数 (8)
IR_RAW_OFF      equ 48     ; 原始字节[4] (4)
IR_SIZE_OFF     equ 52     ; 指令大小 (1)
                            ; = 53 字节 + 3 padding = 56

MAX_IR_ENTRIES  equ 256
