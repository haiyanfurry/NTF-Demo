; ============================================
; config.inc - 跨平台配置 (Windows/Linux)
; 使用方式:
;   nasm -f win64 -DTARGET_WIN64 main.asm  (Windows)
;   nasm -f elf64 main.asm                  (Linux)
;
; 调用约定 (跨平台统一):
;   所有系统调用宏假设参数已在以下寄存器中设置好
;   (Linux x86_64 syscall convention):
;     rdi = 参数1 (fd/句柄, 文件名指针)
;     rsi = 参数2 (缓冲区指针, 标志位)
;     rdx = 参数3 (长度, 模式)
;
; Windows x64 堆栈对齐规则:
;   call 指令前 RSP 必须 16 字节对齐
;   因此宏内 sub rsp, 56:
;     sub rsp, 56 → RSP = 16K-56 = NOT aligned (56 mod 16 = 8)
;     call Func  → RSP = 16K-64 = aligned ✅
;   分配的 56 字节: 32 shadow + 24 栈参数空间
; ============================================

%ifdef TARGET_WIN64
; ========== Windows x64 (PE32+) ==========

; Windows API 常量
STD_INPUT_HANDLE   equ -10
STD_OUTPUT_HANDLE  equ -11
STD_ERROR_HANDLE   equ -12

GENERIC_READ       equ 0x80000000
GENERIC_WRITE      equ 0x40000000
FILE_SHARE_READ    equ 1
OPEN_EXISTING      equ 3
CREATE_ALWAYS      equ 2

; Windows API 函数声明 (kernel32.dll)
extern GetStdHandle
extern WriteFile
extern ReadFile
extern CreateFileA
extern CloseHandle
extern ExitProcess

; --- Windows 系统调用宏 ---
; 所有宏遵循 Linux syscall 参数约定:
;   输入: rdi, rsi, rdx (Linux style)
;   宏内部映射到 Windows x64 调用约定: rcx, rdx, r8, r9
;
; 堆栈对齐: 所有宏使用 sub rsp, 56
;   32 字节 shadow space + 24 字节栈参数空间
;   56 mod 16 = 8, 因此 call 后 RSP = 对齐 ✅

; sys_open: 打开文件
;   输入: rdi = 文件名, rsi = 标志 (兼容 Linux: 0=O_RDONLY, 0x401=O_CREAT|O_WRONLY|O_TRUNC)
;   输出: rax = 句柄 (INVALID_HANDLE_VALUE = -1 表示失败)
%macro sys_open 0
    sub rsp, 56
    mov rcx, rdi           ; lpFileName
    ; 根据 Linux 风格标志映射到 Windows
    test rsi, 0x401        ; 检查是否有 O_CREAT | O_WRONLY
    jz %%open_read
    ; 写入模式
    mov rdx, GENERIC_WRITE
    mov dword [rsp+32], CREATE_ALWAYS
    jmp %%do_open
%%open_read:
    mov rdx, GENERIC_READ
    mov dword [rsp+32], OPEN_EXISTING
%%do_open:
    mov r8, FILE_SHARE_READ
    xor r9, r9             ; lpSecurityAttributes (NULL)
    mov dword [rsp+40], 0  ; dwFlagsAndAttributes
    mov dword [rsp+48], 0  ; hTemplateFile
    call CreateFileA
    add rsp, 56
%endmacro

; sys_read: 读取文件
;   输入: rdi = 句柄, rsi = 缓冲区, rdx = 读取字节数
;   输出: rax = 实际读取字节数
%macro sys_read 0
    mov r10, rdx           ; 保存 count
    sub rsp, 56
    mov rcx, rdi           ; hFile
    mov rdx, rsi           ; lpBuffer
    mov r8, r10            ; nNumberOfBytesToRead
    lea r9, [rsp+48]       ; lpNumberOfBytesRead (位于分配的56字节内)
    mov qword [rsp+32], 0  ; lpOverlapped (NULL)
    call ReadFile
    mov eax, [rsp+48]      ; return bytes read
    add rsp, 56
%endmacro

; sys_write: 写入文件
;   输入: rdi = 句柄, rsi = 缓冲区, rdx = 写入字节数
;   输出: rax = 实际写入字节数
%macro sys_write 0
    mov r10, rdx           ; 保存 count
    sub rsp, 56
    mov rcx, rdi           ; hFile
    mov rdx, rsi           ; lpBuffer
    mov r8, r10            ; nNumberOfBytesToWrite
    lea r9, [rsp+48]       ; lpNumberOfBytesWritten
    mov qword [rsp+32], 0  ; lpOverlapped (NULL)
    call WriteFile
    mov eax, [rsp+48]      ; return bytes written
    add rsp, 56
%endmacro

; sys_close: 关闭句柄
;   输入: rdi = 句柄
%macro sys_close 0
    sub rsp, 56
    mov rcx, rdi
    call CloseHandle
    add rsp, 56
%endmacro

; sys_exit: 退出进程
;   输入: rdi = 退出码
%macro sys_exit 0
    sub rsp, 56
    mov rcx, rdi
    call ExitProcess
    add rsp, 56
%endmacro

; 获取标准输入句柄 -> rax
%macro get_stdin 0
    sub rsp, 56
    mov rcx, STD_INPUT_HANDLE
    call GetStdHandle
    add rsp, 56
%endmacro

; 获取标准输出句柄 -> rax
%macro get_stdout 0
    sub rsp, 56
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    add rsp, 56
%endmacro

; RIP-相对寻址辅助: 加载变量地址
; Windows x64 PE32+ 必须使用 RIP-相对寻址访问全局/静态变量
; 使用: load_addr rbx, my_variable
; 然后: mov rax, [rbx]  或  mov [rbx], rax
%macro load_addr 2
    lea %1, [rel %2]
%endmacro

%else
; ========== Linux x86_64 (ELF64) ==========

; Linux 系统调用号
SYS_READ    equ 0
SYS_WRITE   equ 1
SYS_OPEN    equ 2
SYS_CLOSE   equ 3
SYS_EXIT    equ 60

; --- Linux 系统调用宏 ---
; 参数已在 rdi, rsi, rdx 中
; Linux 系统调用使用 rdi, rsi, rdx, r10, r8, r9
; Linux 不需要特殊的堆栈对齐 (syscall 指令不依赖 RSP)

; sys_open: 打开文件
;   输入: rdi = 文件名, rsi = 标志, rdx = 模式
;   输出: rax = fd
%macro sys_open 0
    mov rax, SYS_OPEN
    syscall
%endmacro

; sys_read: 读取文件
;   输入: rdi = fd, rsi = 缓冲区, rdx = 读取字节数
;   输出: rax = 实际读取字节数
%macro sys_read 0
    mov rax, SYS_READ
    syscall
%endmacro

; sys_write: 写入文件
;   输入: rdi = fd, rsi = 缓冲区, rdx = 写入字节数
;   输出: rax = 实际写入字节数
%macro sys_write 0
    mov rax, SYS_WRITE
    syscall
%endmacro

; sys_close: 关闭文件
;   输入: rdi = fd
%macro sys_close 0
    mov rax, SYS_CLOSE
    syscall
%endmacro

; sys_exit: 退出进程
;   输入: rdi = 退出码
%macro sys_exit 0
    mov rax, SYS_EXIT
    syscall
%endmacro

; Linux 标准文件描述符
%macro get_stdin 0
    mov rax, 0       ; fd 0 = stdin
%endmacro

%macro get_stdout 0
    mov rax, 1       ; fd 1 = stdout
%endmacro

; Linux x86_64 ELF64 可以直接使用符号地址
; 使用: load_addr rbx, my_variable
%macro load_addr 2
    lea %1, [%2]
%endmacro

%endif
