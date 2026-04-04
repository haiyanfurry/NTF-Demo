

section .data
    read_msg db 'Reading file...', 10, 0
    read_len equ $ - read_msg
    error_msg db 'Error: Cannot open file', 10, 0
    error_len equ $ - error_msg

section .bss
    buffer resb 256

section .text
_start:
    ; 检查命令行参数
    mov eax, dword [esp]
    cmp eax, 2
    jne .usage
    
    ; 打开输入文件
    mov eax, 5
    mov ebx, dword [esp+8]
    mov ecx, 0
    int 0x80
    test eax, eax
    js .error
    mov ebx, eax
    
    ; 读取文件
    mov eax, 3
    mov ecx, buffer
    mov edx, 256
    int 0x80
    test eax, eax
    js .error
    
    ; 输出读取的内容
    mov edx, eax
    mov eax, 4
    mov ebx, 1
    mov ecx, buffer
    int 0x80
    
    ; 退出
    mov eax, 1
    xor ebx, ebx
    int 0x80

.usage:
    mov eax, 4
    mov ebx, 2
    mov ecx, error_msg
    mov edx, error_len
    int 0x80
    mov eax, 1
    mov ebx, 1
    int 0x80

.error:
    mov eax, 4
    mov ebx, 2
    mov ecx, error_msg
    mov edx, error_len
    int 0x80
    mov eax, 1
    mov ebx, 1
    int 0x80