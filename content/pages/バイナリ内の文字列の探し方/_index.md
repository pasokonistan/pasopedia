---
title: "バイナリ内の文字列の探し方"
date: 2024-01-26T02:23:48+09:00
type: docs
---

## 本記事の実験環境

- OS: Ubuntu 22.04
- コンパイラ: clang 17.0.6
- アーキテクチャ: x86_64
- GNU readelf: GNU Binutils 2.38

## 文字列

定番のHello, World!プログラムを使って、文字列がどこにあるかみてみよう。

```c
#include <stdio.h>

int main(void) {
    puts("Hello, World!\n");
}
```

まずは-cオプションをつかってリンク前のオブジェクトファイルでみてみよう。

```console
$ clang -c helloworld.c
```

バイナリのセクション情報をみるために、ここではGNU readelfプログラムを利用している。

```console
$ readelf -WS helloworld.o
There are 11 section headers, starting at offset 0x260:

Section Headers:
  [Nr] Name              Type            Address          Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            0000000000000000 000000 000000 00      0   0  0
  [ 1] .strtab           STRTAB          0000000000000000 0001e1 00007f 00      0   0  1
  [ 2] .text             PROGBITS        0000000000000000 000040 000014 00  AX  0   0 16
  [ 3] .rela.text        RELA            0000000000000000 000198 000030 18   I 10   2  8
  [ 4] .rodata.str1.1    PROGBITS        0000000000000000 000054 00000f 01 AMS  0   0  1
  [ 5] .comment          PROGBITS        0000000000000000 000063 000066 01  MS  0   0  1
  [ 6] .note.GNU-stack   PROGBITS        0000000000000000 0000c9 000000 00      0   0  1
  [ 7] .eh_frame         X86_64_UNWIND   0000000000000000 0000d0 000038 00   A  0   0  8
  [ 8] .rela.eh_frame    RELA            0000000000000000 0001c8 000018 18   I 10   7  8
  [ 9] .llvm_addrsig     LOOS+0xfff4c03  0000000000000000 0001e0 000001 00   E 10   0  1
  [10] .symtab           SYMTAB          0000000000000000 000108 000090 18      1   4  8
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  D (mbind), l (large), p (processor specific)
```

readelfの-xオプションを使うと、そのセクションの中身のデータをみることができる。

```console
$ readelf -x .rodata.str1.1 helloworld.o

Hex dump of section '.rodata.str1.1':
  0x00000000 48656c6c 6f2c2057 6f726c64 210a00   Hello, World!..
```

ここで文字列Hello, World!は.rodata.str1.1にあることがわかった。
.rodataは不変なデータを置くグローバルなデータ領域で、文字列はこのセクションに置かれる。

ちなみに.commentセクションはclangの場合はコンパイルに利用したコンパイラの情報が含まれる。

```console
$ readelf -x .comment helloworld.o

Hex dump of section '.comment':
  0x00000000 00636c61 6e672076 65727369 6f6e2031 .clang version 1
  0x00000010 372e302e 36202868 74747073 3a2f2f67 7.0.6 (https://g
  0x00000020 69746875 622e636f 6d2f6c6c 766d2f6c ithub.com/llvm/l
  0x00000030 6c766d2d 70726f6a 65637420 36303039 lvm-project 6009
  0x00000040 37303862 34333637 31373163 63646266 708b4367171ccdbf
  0x00000050 34623539 30356362 36613830 33373533 4b5905cb6a803753
  0x00000060 66653138 2900                       fe18).
```

さて、ここまではリンク前のオブジェクトファイルでバイナリの中身をみてきたが、実行ファイルだとどうだろうか。

```console
$ clang -o helloworld helloworld.c
```

同様にreadelf -WSでセクション情報をみてみる。

```console
$ readelf -WS helloworld
(長いので割愛)
  [14] .text             PROGBITS        0000000000001050 001050 000104 00  AX  0   0 16
  [15] .fini             PROGBITS        0000000000001154 001154 00000d 00  AX  0   0  4
  [16] .rodata           PROGBITS        0000000000002000 002000 000013 00   A  0   0  4
  [17] .eh_frame_hdr     PROGBITS        0000000000002014 002014 00002c 00   A  0   0  4
  [18] .eh_frame         PROGBITS        0000000000002040 002040 000094 00   A  0   0  8
  [19] .init_array       INIT_ARRAY      0000000000003de8 002de8 000008 08  WA  0   0  8
  [20] .fini_array       FINI_ARRAY      0000000000003df0 002df0 000008 08  WA  0   0  8
  [21] .dynamic          DYNAMIC         0000000000003df8 002df8 0001e0 10  WA  6   0  8
  [22] .got              PROGBITS        0000000000003fd8 002fd8 000028 08  WA  0   0  8
  [23] .got.plt          PROGBITS        0000000000004000 003000 000020 08  WA  0   0  8
  [24] .data             PROGBITS        0000000000004020 003020 000010 00  WA  0   0  8
  [25] .bss              NOBITS          0000000000004030 003030 000008 00  WA  0   0  1
```

.rodataセクションはmergeableなので、すべての.rodata.*な情報がまとめられてしまった。

特定の文字列がどこに配置されているかを知りたい場合は、readelf -pを利用するとよい。

```console
$ readelf -p .rodata helloworld

String dump of section '.rodata':
  [     4]  Hello, World!\n
```

-pオプションは指定したセクションの文字列っぽいものを探索し(stringsコマンドのような動きをする)、それをみつけたときにオフセット情報とともに出力してくれる。

今回のプログラムの例では文字列Hello, World!は.rodataセクションの先頭からオフセット4の位置に配置されていることがわかる。

```console
$ readelf -x .rodata helloworld

Hex dump of section '.rodata':
  0x00002000 01000200 48656c6c 6f2c2057 6f726c64 ....Hello, World
  0x00002010 210a00                              !..
```
