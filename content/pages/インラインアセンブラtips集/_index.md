---
title: "インラインアセンブラtips集"
date: 2023-09-22T05:11:29+09:00
type: docs
---

## 本記事で対象とする環境

本記事では以下の環境のインラインアセンブラに関するtipsについて記載する。

- コンパイラ：gcc 11.4.0 以降
- アーキテクチャ：x86-64

なお、インラインアセンブラの基本について解説は行わない。

## Intel syntaxで記述したい

gccはデフォルトではAT&T syntaxで記載されたインラインアセンブリをコンパイルすることができる。
しかしIntel syntaxで記載したいときもある。

その際は、コンパイルオプションに `-masm=intel` を追加すると、Intel syntaxで記載されたインラインアセンブリをコンパイルできる。

また、一部分だけIntel syntaxで記載したい場合は、コンパイルオプションではなく、インラインアセンブリ中に `.intel_syntax noprefix` を記載することで適用することができる。
`.att_syntax` を記載すれば、AT&T syntaxに戻すこともできる。

```c
#include <stdio.h>

int main(void) {
	int a = 1, b;
	asm (
		".intel_syntax noprefix\n"
		"mov %0, %1\n"
		"add %0, 1\n"
		".att_syntax\n"
		"add $1, %0\n"
		: "=r" (b)
		: "r" (a)
	);

	printf ("%d\n", b);
}
```

上記の例では `3` が出力される。

## レジスタに値を割り付けたい

インラインアセンブラでは、レジスタを指定して値を割り付けることができる。
例えば以下の例がある。

```c
uint64_t inline_asm_syscall(
    uint64_t syscall_no,
    uint64_t arg1,
    uint64_t arg2,
    uint64_t arg3,
    uint64_t arg4,
    uint64_t arg5,
    uint64_t arg6,
) {
    uint64_t ret;

    register uint64_t arg4_r10 asm("r10") = arg4;
    register uint64_t arg5_r8  asm("r8")  = arg5;
    register uint64_t arg6_r9  asm("r9")  = arg6;
    asm (
        "syscall"
        : "=a" (ret)
        : "a" (syscall_no),
          "D" (arg1), "S" (arg2), "d" (arg3),
          "r" (arg4_r10), "r" (arg5_r8), "r" (arg6_9)
        : "memory", "rcx", "r11"
    );

    return ret;
}
```

上記の例は `syscall` 命令を発行するインラインアセンブリである。

- `rax` に `syscall_no`
- `rdi` に `arg1`
- `rsi` に `arg2`
- `rdx` に `arg3`
- `r10` に `arg4`
- `r8` に `arg5`
- `r9` に `arg6`

を割り当て、 `syscall` 命令を発行し、返り値を `rax` 経由で `ret` に格納している。

インラインアセンブラでは入力オペランドと出力オペランドでレジスタに値を割り付けることが可能だが、具体的にどのレジスタにどの値を割り付けたいといったことも指定可能である。

以下に表を記す。

| レジスタ名 | オペランド上の表記 |
| ---------- | ------------------ |
| rax        | a                  |
| rbx        | b                  |
| rcx        | c                  |
| rdx        | d                  |
| rsi        | S                  |
| rdi        | D                  |

このように、x86が32bitだった時代から存在するレジスタには、表記方法が存在する。

x86-64になってからは、 `r8` から `r15` までのレジスタが増えた。
これらのレジスタは上記のような表記方法が存在しないため、次のようにレジスタを割り当てる。

```c
    register uint64_t arg4_r10 asm("r10") = arg4;
    register uint64_t arg5_r8  asm("r8")  = arg5;
    register uint64_t arg6_r9  asm("r9")  = arg6;
```

上記の例は、 `register` を用いて `r10` `r8` `r9` レジスタに値を割り当てる表記である。
これらは次のように用いる。

```c
    asm (
        "syscall"
        : "=a" (ret)
        : "a" (syscall_no),
          "D" (arg1), "S" (arg2), "d" (arg3),
          "r" (arg4_r10), "r" (arg5_r8), "r" (arg6_9)
        : "memory", "rcx", "r11"
    );
```

上記のように、 `register` の文で割り当てた名前を用いて、 `"r"` で指定する。
すると、 `syscall` 命令が呼ばれる際に、 `r10` `r8` `r9` に値が割り当てられる。

また、破壊されるレジスタの記載に関しては、そのままレジスタの名前が使える。
今回の場合は `rcx` `r11` である。

## インラインアセンブラだけの関数で、プロローグとエピローグを抑制したい

組み込みなどの特殊環境下では、関数プロローグとエピローグを省略して、インラインアセンブラのみで構成された関数を使いたいといったこともある。
そのような際は、 `__attribute__((naked))` を用いると良い。
以下が例である。

```c
#include <stdio.h>

__attribute__((naked))
void f(void) {
	asm volatile("nop");
}

int main(void) {
	f();
	printf("hello\n");
	return 0;
}
```

上記のように、関数に `__attribute__((naked))` でnaked属性を指定すると、関数プロローグが省略される。
`objdump -d` すると、次のような逆アセンブルが確認できる。

```
0000000000001149 <f>:
    1149:	f3 0f 1e fa          	endbr64 
    114d:	90                   	nop
    114e:	90                   	nop
    114f:	0f 0b                	ud2    

0000000000001151 <main>:
    1151:	f3 0f 1e fa          	endbr64 
    1155:	55                   	push   %rbp
    1156:	48 89 e5             	mov    %rsp,%rbp
    1159:	e8 eb ff ff ff       	call   1149 <f>
    115e:	48 8d 05 9f 0e 00 00 	lea    0xe9f(%rip),%rax        # 2004 <_IO_stdin_used+0x4>
    1165:	48 89 c7             	mov    %rax,%rdi
    1168:	e8 e3 fe ff ff       	call   1050 <puts@plt>
    116d:	b8 00 00 00 00       	mov    $0x0,%eax
    1172:	5d                   	pop    %rbp
    1173:	c3                   	ret    
```

naked属性を指定した関数 `f()` のプロローグとエピローグが消えていることがわかる。

なお、このプログラムは `f()` に突入した後、 `114f:	0f 0b ud2` でSegmentation faultする。
