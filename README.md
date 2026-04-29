# NTF-Demo — 二进制指令到汇编语言的编译器

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-blue)]()
[![Language](https://img.shields.io/badge/language-x86_64%20Assembly-red)]()
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## 概述

**NTF-Demo** 是一个用 **x86-64 汇编语言**编写的编译器，它将自定义二进制指令（`.01` 格式文件）转换为 **NASM 汇编源代码**（`output.asm`）。该编译器使用纯汇编实现，支持 **Windows (PE32+)** 和 **Linux (ELF64)** 双平台构建。

### 核心特性

- ⚡ **纯汇编实现** — 全部使用 NASM x86-64 汇编语言编写，无外部依赖
- 🔄 **双平台支持** — 同一套源码可编译为 Windows 或 Linux 可执行文件
- 📦 **模块化设计** — 核心框架与指令处理模块分离，易于扩展
- 🖨️ **PRINT 指令** — 支持将十六进制编码的字符串输出为 `db` 数据指令
- 💾 **高效 I/O** — 使用 4KB 缓冲区和系统调用直接读写文件

## 快速开始

### 预编译版本

项目 `bin/` 目录包含预编译的可执行文件：

| 文件 | 平台 | 说明 |
|------|------|------|
| `bin/compiler.exe` | Windows x64 | Windows PE32+ 可执行文件 |
| `bin/run.bat` | Windows | 快速运行脚本 |
| `bin/compiler` | Linux x64 | Linux ELF64 可执行文件（需自行构建） |
| `bin/run.sh` | Linux | 快速运行脚本 |

### Windows 快速使用

```bat
cd bin
type ..\tests\test_nop.01 | compiler.exe
type output.asm
```

或者使用运行脚本：

```bat
cd bin
run.bat ..\tests\test_print.01
```

### Linux 快速使用

```bash
cd bin
echo 00000 | ./compiler
cat output.asm
```

或者使用运行脚本：

```bash
./bin/run.sh tests/test_nop.01
```

## 语言指令集

### 指令格式

每条指令由 **5 位二进制操作码** 后跟操作数组成（以空格分隔）：

```
<opcode> [operand1 [operand2]]
```

### 支持指令

| 二进制码 | 指令 | 操作数 | 说明 | 示例 |
|---------|------|--------|------|------|
| `00000` | `nop` | 0 | 空操作（无操作） | `00000` |
| `00001` | `mov` | 2 | 数据传送 | `00001 reg1 reg2` |
| `00010` | `add` | 2 | 加法 | `00010 reg1 reg2` |
| `00011` | `sub` | 2 | 减法 | `00011 reg1 reg2` |
| `00100` | `mul` | 2 | 乘法 | `00100 reg1 reg2` |
| `00110` | `inc` | 1 | 自增 | `00110 reg` |
| `00111` | `dec` | 1 | 自减 | `00111 reg` |
| `01010` | `xor` | 2 | 异或 | `01010 reg1 reg2` |
| `01101` | `jmp` | 1 | 跳转 | `01101 label` |
| `10011` | `push` | 1 | 压栈 | `10011 reg` |
| `10100` | `pop` | 1 | 出栈 | `10100 reg` |
| `10101` | `print` | 1 | 输出字符串（十六进制编码） | `10101 HEXSTRING` |

### PRINT 指令详解

`print` 指令（`10101`）将十六进制编码的字符串转换为汇编 `db` 数据指令。

**输入格式：**

```
10101 <hex_encoded_string>
```

其中 `<hex_encoded_string>` 是字符串每个字符的 ASCII 码的十六进制拼接。

**示例：输出 "Hello World!"**

输入：
```
10101 48656C6C6F20576F726C6421
```

生成输出：
```asm
db 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21
```

**常用 ASCII 编码参考：**

| 字符 | 十六进制 | 字符 | 十六进制 |
|------|---------|------|---------|
| `A`-`Z` | `41`-`5A` | `a`-`z` | `61`-`7A` |
| `0`-`9` | `30`-`39` | 空格 | `20` |
| `!` | `21` | `,` | `2C` |
| `.` | `2E` | `\n` | `0A` |

## 示例

### 示例 1：NOP 指令

输入文件 `tests/test_nop.01`：
```
00000
```

编译后输出 `output.asm`：
```asm
nop
```

### 示例 2：多条指令

输入文件 `tests/test_multiple.01`：
```
00000
00001 rax rbx
00010 rcx rdx
00011 r8 r9
00100 r10 r11
00110 r12
00111 r13
01010 r14 r15
01101 loop_start
10011 rax
10100 rbx
```

编译后输出 `output.asm`：
```asm
nop
mov rax, rbx
add rcx, rdx
sub r8, r9
mul r10, r11
inc r12
dec r13
xor r14, r15
jmp loop_start
push rax
pop rbx
```

### 示例 3：PRINT 指令（Hello World）

输入文件 `tests/hello.01`：
```
10101 48656C6C6F20576F726C6421
00000
```

编译后输出 `output.asm`：
```asm
db 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x21
nop
```

## 构建指南

### 前置条件

- **NASM**（Netwide Assembler）2.x 或更高版本
- **GCC** 或 **LD**（用于链接）
- **Linux 构建**：`elf64` 输出格式
- **Windows 构建**：`win64` 输出格式，需要 MSYS2/MinGW 环境

### Linux 构建

```bash
./build.sh
```

构建产物：`bin/compiler`（同时复制到项目根目录 `./compiler`）

验证构建：
```bash
echo 00000 | ./bin/compiler
cat output.asm
# 预期输出: nop
```

### Windows 构建

在 **MSYS2** 或 **Cygwin** 终端中运行：

```bash
./build_windows.sh
```

构建产物：`bin/compiler.exe`（同时复制到项目根目录 `./compiler.exe`）

如果 `nasm` 不在 PATH 中，脚本会自动搜索常见安装路径（如 `D:/mys32/usr/bin/nasm.exe`）。

### 完整测试验证

运行所有测试用例验证编译器功能：

```bash
# 测试 NOP 指令
echo 00000 | ./bin/compiler && cat output.asm

# 测试所有指令
cat tests/test_multiple.01 | ./bin/compiler && cat output.asm

# 测试 PRINT 指令
cat tests/test_print.01 | ./bin/compiler && cat output.asm

# 测试 Hello World
cat tests/hello.01 | ./bin/compiler && cat output.asm
```

## 项目结构

```
NTF-Demo/
├── bin/                    # 编译输出目录（可执行文件）
│   ├── compiler.exe        # Windows 可执行文件
│   ├── compiler            # Linux 可执行文件
│   ├── run.bat             # Windows 快速运行脚本
│   └── run.sh              # Linux 快速运行脚本
├── tests/                  # 测试用例
│   ├── test_nop.01         # NOP 指令测试
│   ├── test_multiple.01    # 多指令综合测试
│   ├── test_print.01       # PRINT 指令测试
│   ├── hello.01            # Hello World 示例
│   └── test_mov.01         # MOV 指令测试
├── main.asm                # 主入口：文件 I/O 与主循环
├── parse.asm               # 行解析器与令牌分割
├── table.asm               # 指令分发表与查找
├── config.inc              # 跨平台配置宏（include 文件）
├── nop.asm                 # NOP 指令处理
├── mov.asm                 # MOV 指令处理
├── add.asm                 # ADD 指令处理
├── sub.asm                 # SUB 指令处理
├── mul.asm                 # MUL 指令处理
├── inc.asm                 # INC 指令处理
├── dec.asm                 # DEC 指令处理
├── xor.asm                 # XOR 指令处理
├── jmp.asm                 # JMP 指令处理
├── push.asm                # PUSH 指令处理
├── pop.asm                 # POP 指令处理
├── print.asm               # PRINT 指令处理（十六进制→db）
├── build.sh                # Linux 构建脚本
├── build_windows.sh        # Windows 构建脚本
├── run.sh                  # 项目根运行脚本
├── README.md               # 本文档
└── LICENSE                 # 许可证
```

## 架构说明

### 整体流程

```
.01 输入文件
    │
    ▼
parse_line()       ← 逐行读取二进制指令
    │
    ▼
split_tokens()     ← 分割操作码和操作数
    │
    ▼
find_instruction_handler()  ← 查表匹配指令处理函数
    │
    ▼
handle_xxx()       ← 执行指令处理，写入输出
    │
    ▼
output.asm         ← 生成的 NASM 汇编源码
```

### 模块职责

| 模块 | 职责 |
|------|------|
| [`main.asm`](main.asm) | 入口点、文件打开/关闭、主循环调度、缓冲 I/O 实现 |
| [`parse.asm`](parse.asm) | 行读取、令牌分割、输入缓冲区管理 |
| [`table.asm`](table.asm) | 指令分发表（12 条指令）、二分/线性查找 |
| [`config.inc`](config.inc) | 跨平台宏（`sys_read`/`sys_write`/`open_file`/`exit_app`） |
| `nop.asm` ~ `pop.asm` | 各指令的处理函数，写入对应汇编助记符 |
| [`print.asm`](print.asm) | 十六进制字符串解码，输出 `db 0xNN` 格式 |

### 跨平台设计

通过 [`config.inc`](config.inc) 中的条件宏实现双平台支持：

- **Windows**（`TARGET_WIN64` 定义）：使用 `ReadFile`/`WriteFile` API（通过 `kernel32.dll`）
- **Linux**：使用 `sys_read`/`sys_write` 系统调用（int 0x80 或 syscall 指令）
- 构建时通过 `-DTARGET_WIN64` 控制编译路径

### I/O 缓冲区机制

采用 **带缓冲的输出** 设计，避免频繁的系统调用：

- `out_buf`：4096 字节缓冲区
- `write_char`：将字符写入缓冲区，满时自动刷新
- `flush_output`：将缓冲区内容一次性写入输出文件

## 许可证

本项目基于 [Unlicense协议] 开源。

---

---
# 注：
```text
本作者说过！
写出hello world我穿女装
用mp4视频把完整过程给我
我直接把女装照片发README里面
```

**创作者**：haiyanfurry  
**邮箱**：2752842448@qq.com
