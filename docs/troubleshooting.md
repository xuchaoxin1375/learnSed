## 排错与常见陷阱

sed 的错误通常不在“命令有没有跑”，而在“匹配范围对不对、替换文本有没有被改写、shell 有没有提前处理”。这一篇按症状组织，给出先查什么、怎么修、怎么防止再次发生。

遇到问题时，先把输入缩小到一条记录：

```shell
printf 'sample line\n' | sed 's/pattern/replacement/'
```

一条记录能复现，问题就在脚本；一条记录不能复现，问题可能在地址、多行状态或输入格式。

### 症状速查

| 症状 | 常见原因 | 先查 |
| --- | --- | --- |
| 文件内容没有变化 | 没有用 `-i`，只写到了标准输出 | 命令里有没有 `-i` |
| 命中行输出两遍 | `p` 没配合 `-n` | 是否同时有默认打印和 `p` |
| 只替换了第一处 | 没有 `g` | `s///` 后面有没有 `g` |
| 完全匹配不到 | BRE/ERE 写错、元字符没转义、locale 不对 | 用 `-E` 或 `grep` 对照 |
| 替换结果多出原文本 | 替换文本里的 `&` 没转义 | 是否要字面量 `&` |
| `$` 或变量消失了 | 双引号让 shell 先展开 | 改用单引号或转义 |
| 范围输出过长 | 结束正则没匹配、起始行同一行不测试结束 | 用 `=` 看行号，考虑 `0,/re/` |
| `\n` 匹配不到 | 行尾换行不在模式空间 | 先 `N` 或 `G` |
| 中文按字节拆开 | locale 是 `C`/`POSIX` | `locale`、`LC_ALL` |
| 文件被清空 | `-n` 和 `-i` 一起用，没有 `p` | 立即从备份恢复 |
| macOS 报 `-i` 用法错误 | BSD sed 要求后缀参数 | 用 `sed -i ''` 或 `gsed` |
| `N` 丢掉最后一行 | `N` 在 EOF 失败 | 用 `$!N` |
| `y` 只换了一个字符 | `y` 不支持 `a-z` 范围 | 写全字母表或用 `tr` |

### 文件没有变化

sed 默认把结果写到标准输出，不修改输入文件：

```shell
sed 's/8080/9090/' examples/data/config.ini
```

终端会显示修改后的内容，但 `examples/data/config.ini` 本身没有变。要写回文件，用 `-i`：

```shell
cp examples/data/config.ini /tmp/config.ini
sed -i.bak 's/8080/9090/' /tmp/config.ini
```

先用 `diff` 验证：

```shell
diff -u examples/data/config.ini /tmp/config.ini
```

如果没有差异，检查替换是否真的匹配。`sed -n '/8080/p' file` 能确认输入里有没有这个字符串。

### 输出重复

`p` 打印一次，默认打印又一次：

```shell
printf 'a\nb\n' | sed 's/a/A/p'
```

输出 `A`、`A`、`b`。修复方式二选一：加 `-n`，或者去掉 `p`。

```shell
printf 'a\nb\n' | sed -n 's/a/A/p'
```

过滤场景通常用 `-n` 加 `p`；只想改内容、不想筛选时不要加 `p`。

### 只替换一次

`s` 默认只替换每行的第一个匹配：

```shell
printf 'a a a\n' | sed 's/a/A/'
```

输出 `A a a`。要全部替换，加 `g`：

```shell
printf 'a a a\n' | sed 's/a/A/g'
```

只替换第二个用 `s/a/A/2`；从第二个开始全部替换用 `s/a/A/2g`。数字写错不会报错，只是没有替换发生。

### 正则匹配不到

先确认方言。下面三条命令看起来相似，行为不同：

```shell
printf 'aaa\n' | sed -n '/a\+/p'
printf 'aaa\n' | sed -nE '/a+/p'
printf 'aaa\n' | sed -n '/a+/p'
```

前两条匹配 `aaa`，第三条不匹配，因为 BRE 里的 `+` 是普通字符，模式实际是“a 后面跟一个加号”。

常见原因还有：

- 点号没有转义：`dev.local` 会匹配 `devXlocal`。
- 括号或竖线在 BRE 里没有转义：`(cat|dog)` 匹配的是字面括号和竖线。
- 字符类写错：`[:digit:]` 不是字符类，`[[:digit:]]` 才是。
- 使用了 GNU 扩展，但当前是 BSD sed：`\w`、`\b`、`\+` 都不一定可用。
- locale 不对：中文和字符类可能按字节处理。

用 `grep` 做对照时，注意 grep 默认也是 BRE，`grep -E` 才是 ERE。不要拿 `grep -P` 的结果去推断 sed 的行为。

### 替换文本里的 & 与反斜杠

替换文本里的 `&` 表示整个匹配：

```shell
printf 'abc\n' | sed 's/b/[&]/'
```

输出 `a[b]c`。要输出字面量 `&`，写 `\&`：

```shell
printf 'abc\n' | sed 's/b/[\&]/'
```

输出 `a[&]c`。同理，反斜杠本身要写成 `\\`；`\1` 只有在正则里有捕获组时才有意义。

如果替换结果出现“匹配内容被插进了不该出现的位置”，第一反应就是检查 `&`。

### shell 引号

sed 脚本建议默认用单引号：

```shell
sed 's/$/;/' examples/data/poem.txt
```

单引号里的 `$`、`*`、`&` 原样传给 sed。需要注入变量时才用双引号：

```shell
name=Alice
sed "s/{{NAME}}/$name/" examples/data/template.txt
```

双引号会让 shell 先展开 `$name`、命令替换和部分反斜杠。下面两种写法结果不同：

```shell
sed 's/$/;/' file
sed "s/$/;/" file
```

在这个例子里，`$/` 后面不是合法变量名，shell 通常会把 `$` 当字面量；但只要 `$` 后面跟着变量名，就会被展开。写不确定的脚本时，先用单引号；确实要变量时，再逐段加双引号。

| 场景 | 推荐写法 | 原因 |
| --- | --- | --- |
| 固定脚本 | 单引号 | 不让 shell 解释 `$`、`&`、反斜杠 |
| 注入变量 | 双引号 | 需要 shell 展开 |
| 脚本含单引号 | 双引号加转义，或写成 `-f` 文件 | 避免引号嵌套 |
| 复杂多行脚本 | `-f` 文件 | 可读、可审查、可测试 |
| 变量值含 `&` 或分隔符 | 不要直接拼接 | 替换文本有特殊语义 |

### 地址范围不对

范围太长，通常有三种原因：

- 结束正则没有匹配，范围一直到 EOF。
- 起始行本身也能匹配结束正则，但 sed 从下一行才开始测试结束条件。
- 范围重复匹配，最后一段延伸到 EOF。

用 `=` 看行号：

```shell
sed -n '/start/,/end/{=;p}' examples/data/block.txt
```

如果只想处理第一次出现，用 **GNU** 的 `0,/re/`：

```shell
sed '0,/^a=/s/=.*/=0/' file
```

如果结束条件是行号而不是正则，用 `addr,+N` 或 `addr,~N`，比写一个可能不存在的结束正则更稳。

### 换行与 CRLF

普通输入行的行尾换行不在模式空间里，所以 `s/\n/+/` 不会把两行合并。先 `N`：

```shell
printf 'a\nb\n' | sed 'N;s/\n/+/'
```

CRLF(Carriage Return + Line Feed, 回车换行) 文件在 Unix 上会在行尾留下 `\r`。标准处理是：

```shell
sed 's/\r$//' file.txt
```

但 Windows 的 Git Bash 可能以文本模式读入并自动处理 CRLF，导致这条命令看起来“没有变化”。**GNU** 的 `-b` 或 `--binary` 可以让 sed 按二进制模式打开输入，把 CR 留在模式空间里：

```shell
sed -b 's/\r$//' file.txt
```

用 `sed -b -n 'l' file.txt` 查看时，行尾会显示 `\r$`，可以确认 CR 确实在模式空间里。先用字节确认输入里到底有没有 CR：

```shell
printf 'a\r\n' | od -An -c
```

输出里能看到 `\r` 和 `\n`。处理完后再用 `od` 或 `file` 确认。跨平台脚本不要假设 sed 一定保留 CR，也不要把 `-b` 当作所有平台都需要的开关。

### 中文、locale 与编码

如果 `.` 匹配的不是一个汉字，而是三个 `X`，说明当前是字节模式：

```shell
locale
LC_ALL=C.UTF-8 sed 's/./X/g' examples/data/unicode.txt
LC_ALL=C sed 's/./X/g' examples/data/unicode.txt
```

UTF-8 locale 下按字符处理，`C` locale 下按字节处理。默认 locale 未设置时，实际行为可能偏向字节；用上面的对比确认。需要按字符处理时设置 UTF-8 locale：

```shell
export LC_ALL=C.UTF-8
```

不是每个系统都有这个名字；先 `locale -a` 查可用值。设置后重新运行命令。注意 `[[:alpha:]]` 在 UTF-8 locale 下可能把中文也算作字母，这会影响匹配范围。

### -i 把文件清空

这是最危险的组合之一：

```shell
sed -n -i 's/a/A/' file
```

`-i` 写回 sed 的输出，`-n` 关闭默认输出，脚本里又没有 `p`，所以没有任何行被写回，文件变成空文件。

修复方式是不要在这种情况下加 `-n`，或者在 `-n` 脚本里显式 `p` 出每一行：

```shell
sed -n -i 's/a/A/p' file
```

但后者只写回发生替换的行，其他行仍然会丢失。最稳妥的做法是：批量修改时不要用 `-n`；需要筛选时，先用不带 `-i` 的命令预览。

如果已经清空，立即停止后续写入，从 `-i.bak`、Git 或备份恢复。没有备份时，检查文件系统快照或版本控制历史。

### 符号链接、硬链接与权限

`-i` 会创建临时文件再替换原文件，因此：

- 硬链接会被拆开，其他硬链接仍指向旧内容。
- 符号链接可能被替换成普通文件，而不是修改链接目标。
- 需要对链接目标生效时，用 **GNU** 的 `--follow-symlinks`，并用 `ls -l` 确认操作前后的链接关系。
- 目录没有写权限时，即使文件本身可写，`-i` 也可能失败，因为它需要在同一目录创建临时文件。

这些行为依赖平台和文件系统。操作前先 `ls -l`、`stat`，在副本上验证。

### 平台差异

macOS 自带 BSD sed，常见报错来自 `-i`：

```shell
sed -i 's/foo/bar/' file
```

BSD sed 要求 `-i` 带参数，正确写法是不保留备份：

```shell
sed -i '' 's/foo/bar/' file
```

GNU sed 的 `-i.bak` 在 BSD sed 上不通用。跨平台脚本要么检测版本，要么显式调用 `gsed`。

其他常见差异：

- BSD sed 不支持 `0,/re/`、`addr,+N`、`-z`、`--debug`。
- BSD sed 的 BRE 通常不支持 `\+`、`\?`、`\|`。
- BSD sed 的 `a`/`i`/`c` 要求反斜杠加换行。
- BSD sed 的扩展正则选项通常是 `-E`，没有 `-r`。

### 语法错误与退出码

常见错误信息：

```shell
sed: -e expression #1, char 5: unterminated `s' command
sed: -e expression #1, char 1: unknown command: `X'
sed: -e expression #1, char 9: strings for `y' command are different lengths
sed: -e expression #1, char 2: invalid usage of line address 0
sed: -e expression #1, char 7: unknown option to `s'
sed: -e expression #1, char 0: no previous regular expression
```

排查顺序：

- `s` 的分隔符是否成对，替换文本里是否漏了转义。
- `y` 的源集合和目标集合长度是否相同。
- 地址 `0` 是否只用在 `0,/re/` 里。
- `s` 的 flag 是否拼错。
- `//` 是否在还没有任何正则时使用。

退出码：

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功 |
| `1` | 脚本或参数错误 |
| `2` | 文件打不开 |
| `4` | 读写出错，例如把目录当文件读 |

管道里 sed 失败时，后面命令的成功可能掩盖它。bash 可以用 `set -o pipefail`，或者检查 `PIPESTATUS`。

### 调试流程

按下面的顺序缩小问题：

1. 用 `printf` 构造一条最小输入，确认脚本本身。
2. 用 `sed --debug` 看模式空间、命中的命令和正则寄存器。
3. 用 `sed -n 'l'` 或 `od -An -c` 看不可见字符。
4. 用 `sed -n '/re/='` 看匹配行的行号。
5. 用 `diff -u` 比较修改前后，确认实际改动范围。
6. 用 `LC_ALL=C` 和 UTF-8 locale 各跑一次，判断是否编码问题。
7. 用 `--sandbox` 运行不完全信任的脚本，禁止 `e`、`r`、`w`。
8. shell 包装脚本用 `bash -x` 看实际参数，避免引号层数出错。

一个典型组合：

```shell
printf 'a "x" b "y"\n' | sed --debug -E 's/.*"([^"]*)".*/\1/'
```

先看 sed 是否匹配、捕获组是什么，再判断输出是否符合预期。

### 恢复

修改文件前的安全措施，按可靠性排序：

- 版本控制：`git diff` 可以查看改动，`git restore` 可以回滚。
- `-i.bak`：备份就在原文件旁边，恢复最直接。
- 手动复制：把文件复制到另一目录，确认后再覆盖。
- 文件系统快照：依赖环境，不能当作默认保障。

恢复后重新运行预览命令，确认内容正确，再决定是否重试。不要在没有备份的原文件上反复试错。

### 练习

- 下面命令为什么会让文件清空？怎么改？

```shell
sed -n -i 's/foo/bar/' file
```

- 下面命令为什么只替换了 `a`，没有把 `abc` 全部转成大写？

```shell
printf 'abc\n' | sed 'y/a-z/A-Z/'
```

- 下面命令在单行输入上为什么输出到 EOF？怎么只处理第一行？

```shell
printf 'start\n' | sed -n '/start/,/start/p'
```

- 下面命令为什么可能把 `$HOME` 展开成路径？怎么避免？

```shell
sed "s/$HOME/\/root/" file
```

<details>
<summary>参考答案</summary>

第一条：`-i` 写回 sed 的输出，`-n` 关闭默认输出，脚本没有 `p`，所以文件被写成空。批量修改去掉 `-n`；需要筛选时先不带 `-i` 预览，或在 `-n` 脚本里显式输出每一行。

第二条：`y` 不把 `a-z` 当范围，而是当成 `a`、`-`、`z` 三个字符，所以只映射了 `a` 和 `z`。写全字母表，或用 `tr 'a-z' 'A-Z'`。

第三条：`addr2` 是正则时，sed 从起始行的下一行开始测试结束条件；单行输入没有下一行，范围延伸到 EOF。用 `0,/start/` 只处理第一行。

第四条：双引号让 shell 先展开 `$HOME`，sed 收到的是路径而不是字面量。需要匹配字面量 `$HOME` 时用单引号，或者把 `$` 转义。更稳妥的是把脚本写进 `-f` 文件。

</details>

下一篇：[速查表](cheatsheet.md)。
