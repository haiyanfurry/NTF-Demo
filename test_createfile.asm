; Minimal CreateFileA test - fixed stack alignment
default rel

extern GetStdHandle
extern WriteFile
extern CreateFileA
extern CloseHandle
extern ExitProcess

STD_OUTPUT_HANDLE equ -11
GENERIC_READ     equ 0x80000000
FILE_SHARE_READ  equ 1
OPEN_EXISTING    equ 3

section .data
test_path   db "cpu_examples\8bit_example.hdr", 0
ok_msg      db "OK: File opened successfully!", 13, 10
ok_len      equ $ - ok_msg
fail_msg    db "FAIL: CreateFileA returned INVALID_HANDLE", 13, 10
fail_len    equ $ - fail_msg

section .text
global _start
_start:
    ; Entry: RSP = 8 mod 16
    ; Need N ≡ 8 mod 16 so RSP becomes 0 mod 16
    ; 56 bytes: 32 shadow + 24 for 3 stack params
    sub rsp, 56        ; RSP = 8-56 = -48 ≡ 0 mod 16 ✓

    ; Try to open file
    lea rcx, [rel test_path]     ; lpFileName
    mov rdx, GENERIC_READ        ; dwDesiredAccess
    mov r8, FILE_SHARE_READ      ; dwShareMode
    xor r9, r9                   ; lpSecurityAttributes (NULL)
    mov dword [rsp+32], OPEN_EXISTING  ; dwCreationDisposition
    mov dword [rsp+40], 0             ; dwFlagsAndAttributes
    mov dword [rsp+48], 0             ; hTemplateFile
    call CreateFileA                   ; RSP before = 0 mod 16 ✓

    ; Check result
    cmp rax, -1
    je .error

    ; Success!
    mov r12, rax           ; save file handle

    ; Get stdout handle
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov r15, rax

    ; Write success message
    mov rcx, r15
    lea rdx, [rel ok_msg]
    mov r8, ok_len
    xor r9, r9             ; lpOverlapped = NULL
    mov qword [rsp+32], 0
    call WriteFile

    ; Close file
    mov rcx, r12
    call CloseHandle

    mov rcx, 0
    call ExitProcess

.error:
    ; Get stdout handle
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov r15, rax

    ; Write fail message
    mov rcx, r15
    lea rdx, [rel fail_msg]
    mov r8, fail_len
    xor r9, r9
    mov qword [rsp+32], 0
    call WriteFile

    mov rcx, 1
    call ExitProcess
