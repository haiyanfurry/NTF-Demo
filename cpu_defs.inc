; ============================================
; cpu_defs.inc - CPU 头文件 DSL 数据结构常量定义
; ============================================
; 本文件由 cpuhdr.asm 和 decode.asm 共享
; ============================================

; --- 指令表常量 ---
INSN_ENTRY_SIZE     equ 32   ; 每条指令 32 字节
INSN_MASK_OFF       equ 0    ; mask     (8 字节)
INSN_PATTERN_OFF    equ 8    ; pattern  (8 字节)
INSN_NAME_OFF       equ 16   ; name_ptr (8 字节)
INSN_OPCOUNT_OFF    equ 24   ; op_count (1 字节)
INSN_OPS_OFF        equ 25   ; op_fields[7] (7 字节, 字段索引数组)

MAX_INSTRUCTIONS    equ 64
MAX_FIELDS          equ 16
MAX_VALUES          equ 16

; --- 字段表常量 ---
FIELD_ENTRY_SIZE    equ 24
FIELD_NAME_OFF      equ 0    ; name_ptr   (8 字节)
FIELD_BITMASK_OFF   equ 8    ; bitmask    (8 字节)
FIELD_SHIFT_OFF     equ 16   ; shift      (1 字节)
FIELD_VALCOUNT_OFF  equ 17   ; val_count  (1 字节)
FIELD_IS_IMM_OFF    equ 18   ; is_imm     (1 字节)
FIELD_VALTAB_OFF    equ 19   ; val_table_ptr (8 字节, 调整对齐)
; 注意: 24 字节对齐

; --- 值表常量 ---
VALUE_ENTRY_SIZE    equ 16
VALUE_PATTERN_OFF   equ 0    ; pattern   (8 字节)
VALUE_NAME_OFF      equ 8    ; name_ptr  (8 字节)
