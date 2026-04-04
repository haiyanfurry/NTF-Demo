
section .text
extern out_fd
extern out_buf
flush_output:
    mov eax, 4
    mov ebx, [out_fd]
    mov ecx, out_buf
    mov edx, 256
    int 0x80
    ret

